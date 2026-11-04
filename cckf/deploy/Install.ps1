param(
    [switch]$RepairOnly,
    [switch]$DeferLaunch,
    [string]$DeploymentConfigPath = (Join-Path $PSScriptRoot 'deployment.private.json'),
    [string]$PasswordFile
)
$ErrorActionPreference = 'Stop'
function Invoke-RustDeskCli {
    param([string]$Executable,[string[]]$CliArguments,[int]$TimeoutMilliseconds=30000)
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Executable
    # Deployment arguments are single tokens without whitespace or embedded quotes.
    foreach ($argument in $CliArguments) {
        if ($argument -match '[\s"]') { throw 'Unsupported CLI argument quoting.' }
    }
    $startInfo.Arguments = $CliArguments -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw 'Could not start RustDesk CLI.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) { throw 'RustDesk command exceeded its timeout.' }
        # A descendant inheriting stdout must not cause another unbounded wait.
        if (-not $stdout.Wait(3000) -or -not $stderr.Wait(3000)) { throw 'RustDesk command did not close its output streams.' }
        return [pscustomobject]@{ExitCode=$process.ExitCode;StdOut=([string]$stdout.Result);StdErr=([string]$stderr.Result)}
    } finally { $process.Dispose() }
}

function Wait-RustDeskReady {
    param([int]$TimeoutSeconds = 180)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $stableCount = 0
    $lastStart = [datetime]::MinValue
    do {
        $info = Get-CimInstance Win32_Service -Filter "Name='RustDesk'" -ErrorAction SilentlyContinue
        $isFinalService = $info -and ($info.PathName -match '(?i)(?:^|\s)--service(?:\s|$)')
        if ($isFinalService -and $info.State -eq 'Running') {
            $stableCount++
            if ($stableCount -ge 3) { return }
        } else {
            $stableCount = 0
            # The installer temporarily uses this service for --import-config.
            # Do not start or change it until its final --service path is present.
            if ($isFinalService -and $info.State -eq 'Stopped' -and ((Get-Date) - $lastStart).TotalSeconds -ge 10) {
                $lastStart = Get-Date
                try { Start-Service -Name RustDesk -ErrorAction Stop } catch {
                    Write-Host 'Service is transitioning; waiting before checking again...'
                }
            }
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    $lastInfo = Get-CimInstance Win32_Service -Filter "Name='RustDesk'" -ErrorAction SilentlyContinue
    if ($lastInfo) {
        throw "RustDesk did not become ready. State=$($lastInfo.State); ExitCode=$($lastInfo.ExitCode); Path=$($lastInfo.PathName)"
    }
    throw 'RustDesk service was not created before the timeout.'
}

function Read-RustDeskOptions {
    param([string]$Path)
    $options = @{}
    $inOptions = $false
    foreach ($line in @(Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop)) {
        if ($null -eq $line) { continue }
        if ($line -match '^\s*\[([^\]]+)\]\s*(?:#.*)?$') { $inOptions = $Matches[1] -eq 'options'; continue }
        if (-not $inOptions) { continue }
        if ($line -match '^\s*([A-Za-z0-9_-]+)\s*=\s*(.+?)\s*$') {
            $key = $Matches[1]
            $value = [string]$Matches[2]
            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                try { $options[$key] = [string]($value | ConvertFrom-Json -ErrorAction Stop) } catch {}
            } elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
                $options[$key] = $value.Substring(1,$value.Length-2)
            }
        }
    }
    return $options
}
function Test-RustDeskExpectedOptions {
    param([hashtable]$Actual,[hashtable]$Expected)
    foreach ($key in $Expected.Keys) {
        if ($null -eq $Actual) { return $false }
        if ($Expected[$key] -eq '' -and -not $Actual.ContainsKey($key)) { continue }
        if (-not $Actual.ContainsKey($key) -or $Actual[$key] -cne $Expected[$key]) { return $false }
    }
    return $true
}
function Confirm-RustDeskOptions {
    param([string]$Executable,[hashtable]$Expected)
    $diagnostic = [Collections.Generic.List[string]]::new()
    $account = (Get-CimInstance Win32_Service -Filter "Name='RustDesk'").StartName
    $diagnostic.Add('Service account: ' + $account)
    $roots = @()
    switch -Regex ($account) {
        '^(LocalSystem|NT AUTHORITY\\SYSTEM)$' {
            $roots += (Join-Path $env:WINDIR 'System32\config\systemprofile\AppData\Roaming')
            $roots += (Join-Path $env:WINDIR 'SysWOW64\config\systemprofile\AppData\Roaming')
            # RustDesk releases can use the LocalService profile for service config.
            $roots += (Join-Path $env:WINDIR 'ServiceProfiles\LocalService\AppData\Roaming')
        }
        'LocalService|LOCAL SERVICE' { $roots += (Join-Path $env:WINDIR 'ServiceProfiles\LocalService\AppData\Roaming') }
        'NetworkService|NETWORK SERVICE' { $roots += (Join-Path $env:WINDIR 'ServiceProfiles\NetworkService\AppData\Roaming') }
    }
    $paths = @($roots | ForEach-Object { Join-Path $_ 'RustDesk\config\RustDesk2.toml' })
    $cliConfirmed = $true
    foreach ($key in $Expected.Keys) {
        $query = Invoke-RustDeskCli -Executable $Executable -CliArguments @('--option',$key) -TimeoutMilliseconds 15000
        $raw = [string]$query.StdOut
        $stderr = [string]$query.StdErr
        $diagnostic.Add('Query ' + $key + ': exit=' + $query.ExitCode + '; stdout=' + ([string]$raw).Trim() + '; stderr=' + ([string]$stderr).Trim())
        $lines = @($raw -split '\r?\n' | ForEach-Object { ([string]$_).Trim() })
        # An empty output is not proof that the API server was cleared.
        if ($Expected[$key] -eq '' -or $query.ExitCode -ne 0 -or $lines -cnotcontains $Expected[$key]) { $cliConfirmed = $false }
    }
    for ($attempt=0; $attempt -lt 15; $attempt++) {
        foreach ($path in $paths) {
            if (Test-Path -LiteralPath $path) {
                $actual = Read-RustDeskOptions -Path $path
                if (Test-RustDeskExpectedOptions -Actual $actual -Expected $Expected) {
                    Write-Host ('Verified service settings in ' + $path)
                    return
                }
            }
        }
        Start-Sleep -Seconds 1
    }
    # Keep a whitelist-only report: do not dump config/password material.
    foreach ($path in $paths) {
        $diagnostic.Add('Service configuration: ' + $path + '; exists=' + (Test-Path -LiteralPath $path))
        if (Test-Path -LiteralPath $path) {
            $actual = Read-RustDeskOptions -Path $path
            foreach ($key in $Expected.Keys) { $diagnostic.Add('  ' + $key + '=' + [string]$actual[$key]) }
        }
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not $desktop) { $desktop = $env:TEMP }
    $report = Join-Path $desktop 'CCKF-RustDesk-Setup-Check.txt'
    $diagnostic | Set-Content -LiteralPath $report -Encoding UTF8
    throw ('Could not verify all service settings. Diagnostic report: ' + $report)
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        $elevatedArguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath)
        if ($RepairOnly) { $elevatedArguments += ' -RepairOnly' }
        $elevatedArguments += ' -DeferLaunch'
        if ($DeploymentConfigPath.Contains('"') -or ([string]$PasswordFile).Contains('"')) { throw 'Invalid file path.' }
        $elevatedArguments += (' -DeploymentConfigPath "{0}"' -f [IO.Path]::GetFullPath($DeploymentConfigPath))
        if ($PasswordFile) { $elevatedArguments += (' -PasswordFile "{0}"' -f [IO.Path]::GetFullPath($PasswordFile)) }
        $child = Start-Process powershell.exe -Verb RunAs -ArgumentList $elevatedArguments -PassThru
        if (-not $child.WaitForExit(600000)) { throw 'Elevated setup exceeded ten minutes.' }
        if ($child.ExitCode -eq 0) {
            $uiExe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
            Start-Process -FilePath $uiExe | Out-Null
        }
        exit $child.ExitCode
    } catch {
        Write-Host 'Administrator approval was cancelled or failed.'
        exit 1
    }
}
try {
    . (Join-Path $PSScriptRoot 'DeploymentConfig.ps1')
    $deployment = Read-DeploymentConfig -Path $DeploymentConfigPath
    if ($PasswordFile) {
        $plainPassword = [IO.File]::ReadAllText([IO.Path]::GetFullPath($PasswordFile)).TrimEnd("`r","`n")
    } else {
        $securePassword = Read-Host 'Administrator: enter the permanent access password' -AsSecureString
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        try { $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    }
    if ([string]::IsNullOrWhiteSpace($plainPassword) -or $plainPassword -match '[\s"]') {
        throw 'This deployment template requires a nonempty password without whitespace or double quotes.'
    }
    Write-Host 'This will install/configure RustDesk, use the selected server, and replace the permanent access password.'
    if (-not $RepairOnly) {
    $installer = Join-Path $PSScriptRoot 'rustdesk-1.5.1-x86_64.exe'
    if (-not (Test-Path -LiteralPath $installer)) { throw 'Extract the entire ZIP before running Install.cmd.' }
    $expectedHash = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'installer.sha256') -Raw).Trim()
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Installer checksum mismatch.' }
    Write-Host 'Installing RustDesk 1.5.1...'
    $installProcess = Start-Process -FilePath $installer -ArgumentList '--silent-install' -PassThru
    if (-not $installProcess.WaitForExit(120000)) { throw 'RustDesk command timed out. No further settings were applied.' }
    if ($installProcess.ExitCode -ne 0) { throw "Installer returned $($installProcess.ExitCode)." }
    }
    $installedExe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
    Write-Host 'Waiting for installation and the final RustDesk service to become ready...'
    Wait-RustDeskReady -TimeoutSeconds 180
    if (-not (Test-Path -LiteralPath $installedExe)) { throw 'The final service is running, but the expected installed executable is missing.' }
    Start-Sleep -Seconds 3
    $settings = @{host=$deployment.host;relay=$deployment.relay;api=$deployment.api;key=$deployment.key} | ConvertTo-Json -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($settings)).TrimEnd('=').Replace('+','-').Replace('/','_')
    $characters = $encoded.ToCharArray()
    [Array]::Reverse($characters)
    $configString = -join $characters
    Write-Host 'Applying server settings...'
    $configProcess = Invoke-RustDeskCli -Executable $installedExe -CliArguments @('--config', $configString)
    if ($configProcess.ExitCode -ne 0) { throw "Configuration command returned $($configProcess.ExitCode)." }
    Write-Host 'Setting permanent password...'
    $passwordProcess = Invoke-RustDeskCli -Executable $installedExe -CliArguments @('--password', $plainPassword)
    if ($passwordProcess.ExitCode -ne 0) { throw "Password command returned $($passwordProcess.ExitCode)." }
    Write-Host 'Selecting permanent-password verification...'
    $modeProcess = Invoke-RustDeskCli -Executable $installedExe -CliArguments @('--option', 'verification-method', 'use-permanent-password')
    if ($modeProcess.ExitCode -ne 0) { throw "Verification-mode command returned $($modeProcess.ExitCode)." }
    Write-Host 'Checking saved service settings...'
    $expectedOptions = @{
        'custom-rendezvous-server' = $deployment.host
        'relay-server' = $deployment.relay
        'api-server' = $deployment.api
        'key' = $deployment.key
        'verification-method' = 'use-permanent-password'
    }
    Confirm-RustDeskOptions -Executable $installedExe -Expected $expectedOptions
    Write-Host 'Server, public key, and permanent-password mode confirmed.'
    Write-Host ('ID server: ' + $deployment.host)
    if (-not $DeferLaunch) {
        Write-Host 'Opening RustDesk. Your ID is shown on the home screen.'
        Start-Process -FilePath $installedExe | Out-Null
    }
    exit 0
} catch {
    $failureText = ($_.Exception.Message + "`r`n" + $_.InvocationInfo.PositionMessage + "`r`n" + $_.ScriptStackTrace)
    if ($plainPassword) { $failureText = $failureText.Replace($plainPassword,'[redacted]') }
    $failureFolder = [Environment]::GetFolderPath('Desktop')
    if (-not $failureFolder) { $failureFolder = $env:TEMP }
    $failurePath = Join-Path $failureFolder 'CCKF-RustDesk-Setup-Error.txt'
    try {
        [IO.File]::WriteAllText($failurePath,$failureText,[Text.Encoding]::UTF8)
        Write-Host ('Error report: ' + $failurePath)
    } catch {
        $failurePath = Join-Path $env:TEMP 'CCKF-RustDesk-Setup-Error.txt'
        [IO.File]::WriteAllText($failurePath,$failureText,[Text.Encoding]::UTF8)
        Write-Host ('Error report: ' + $failurePath)
    }
    Write-Host ('Setup failed: ' + $failureText) -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}











