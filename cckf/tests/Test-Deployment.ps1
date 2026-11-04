$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$deploy = Join-Path $sourceRoot 'cckf/deploy'
foreach ($file in Get-ChildItem -LiteralPath $deploy -Filter '*.ps1') {
    $tokens=$null; $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
. (Join-Path $deploy 'DeploymentConfig.ps1')
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('cckf-config-test-' + [guid]::NewGuid().ToString() + '.json')
try {
    $key = [Convert]::ToBase64String([byte[]](0..31))
    @{host='support.example.org';relay='support.example.org';api='';key=$key} | ConvertTo-Json | Set-Content -LiteralPath $temporary -Encoding UTF8
    $config = Read-DeploymentConfig -Path $temporary
    if ($config.host -ne 'support.example.org' -or $config.key -cne $key) { throw 'Valid config was not preserved.' }
    @{host='support.example.org';relay='';api='';key=$key;password='placeholder-only'} | ConvertTo-Json | Set-Content -LiteralPath $temporary -Encoding UTF8
    $rejected=$false
    try { Read-DeploymentConfig -Path $temporary | Out-Null } catch { $rejected=$true }
    if (-not $rejected) { throw 'Embedded password property was accepted.' }
    $rejected=$false
    try { Read-DeploymentConfig -Path (Join-Path $deploy 'deployment.example.json') | Out-Null } catch { $rejected=$true }
    if (-not $rejected) { throw 'Unconfigured example was accepted.' }
} finally { Remove-Item -LiteralPath $temporary -ErrorAction SilentlyContinue }
$installPath = Join-Path $deploy 'Install.ps1'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($installPath,[ref]$tokens,[ref]$errors)
foreach ($name in @('Invoke-RustDeskCli','Read-RustDeskOptions','Test-RustDeskExpectedOptions')) {
    $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    if (-not $definition) { throw "Missing deployment helper: $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}
$query = Invoke-RustDeskCli -Executable $env:ComSpec -CliArguments @('/c','exit','0')
if ($null -eq $query -or $query.ExitCode -ne 0 -or $null -eq $query.StdOut) { throw 'Empty CLI output regression.' }
if (Test-RustDeskExpectedOptions -Actual $null -Expected @{mode='expected'}) { throw 'Null settings were accepted.' }
if (Test-RustDeskExpectedOptions -Actual @{key='abc='} -Expected @{key='ABC='}) { throw 'Public-key comparison lost case sensitivity.' }
$text = Get-Content -LiteralPath $installPath -Raw
if ($text -match 'Start-Process[^\r\n]*\s-Wait\b') { throw 'Process-tree wait reintroduced.' }
if ($text -notmatch 'Read-DeploymentConfig -Path \$DeploymentConfigPath') { throw 'Private configuration is not loaded.' }
$candidateFiles = Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'cckf') -Recurse -File
foreach ($file in $candidateFiles) {
    if ($file.Name -match '\.(pfx|p12|password|secret)$' -or $file.Name -eq 'deployment.private.json') { throw 'A private deployment file is present in the source bundle.' }
    if ((Get-Content -LiteralPath $file.FullName -Raw) -match ('A'+'fni\.[0-9]')) { throw 'Organization-specific password found in public files.' }
}
Write-Output 'PASS: PowerShell syntax, external configuration, secret exclusions, CLI empty output, null settings, and exact key comparison.'
