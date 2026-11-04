function Read-DeploymentConfig {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw 'Create deployment.private.json from deployment.example.json before installing.' }
    $config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $allowed = @('host','relay','api','key')
    foreach ($property in $config.PSObject.Properties.Name) {
        if ($property -notin $allowed) { throw 'Deployment config may contain only host, relay, api and key. Supply passwords separately.' }
    }
    if ([string]::IsNullOrWhiteSpace([string]$config.host)) { throw 'An ID server is required.' }
    if ([string]$config.host -match '(?i)example\.invalid|\s|["\\/]') { throw 'Replace the example ID server with a valid hostname or IP, optionally including its port.' }
    if ([string]$config.relay -match '\s|["\\/]') { throw 'Invalid relay server.' }
    if ($config.api -and [string]$config.api -notmatch '^https?://[^\s"]+$') { throw 'The API server must be empty or an HTTP(S) URL.' }
    try { $keyBytes = [Convert]::FromBase64String([string]$config.key) } catch { throw 'The public key must be Base64.' }
    if ($keyBytes.Length -ne 32) { throw 'The server public key must contain 32 bytes.' }
    return [pscustomobject]@{host=[string]$config.host;relay=[string]$config.relay;api=[string]$config.api;key=[string]$config.key}
}
