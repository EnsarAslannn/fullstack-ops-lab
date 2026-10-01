$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$preflight = Join-Path $root 'scripts/Module9.EnvPreflight.ps1'
$realEnv = Join-Path $root '.env'
$realEnvHash = if (Test-Path -LiteralPath $realEnv) { (Get-FileHash -Algorithm SHA256 -LiteralPath $realEnv).Hash } else { $null }
$originalFakePassword = [Environment]::GetEnvironmentVariable('MODULE9_FAKE_PASSWORD', 'Process')
$originalPostgresPassword = [Environment]::GetEnvironmentVariable('POSTGRES_PASSWORD', 'Process')
$canary = 'module9-fixture-' + [guid]::NewGuid().ToString('N')
$fixtures = [System.Collections.Generic.List[string]]::new()

function Invoke-Case([string]$Name, [AllowNull()][string]$Contents,
    [bool]$ShouldPass, [string]$ExpectedKey) {
    $ErrorActionPreference = 'Continue'
    $path = Join-Path $root ('.env.module9-fixture-' + [guid]::NewGuid().ToString('N'))
    $fixtures.Add($path)
    if ($Name -ne 'missing .env') {
        [System.IO.File]::WriteAllText($path, $Contents, [System.Text.UTF8Encoding]::new($false))
    }
    $before = if (Test-Path -LiteralPath $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash } else { $null }
    $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File $preflight -EnvFile $path 2>&1 | Out-String)
    $code = $LASTEXITCODE
    if ($output.Contains($canary)) { throw "$Name leaked the fake password" }
    if ($ShouldPass -and $code -ne 0) { throw "$Name should pass (exit=$code)" }
    if (-not $ShouldPass -and $code -eq 0) { throw "$Name should fail" }
    if ($ExpectedKey -and -not $output.Contains($ExpectedKey)) {
        throw "$Name did not name the problematic key"
    }
    $after = if (Test-Path -LiteralPath $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash } else { $null }
    if ($before -ne $after) { throw "$Name changed its input file" }
    Write-Output "PASS $Name (exit=$code, canary hidden, fixture unchanged)"
}

$base = "POSTGRES_USER=fixture_user`nPOSTGRES_DB=fixture_db`nASPNETCORE_ENVIRONMENT=Development`nCache__TasksTtlSeconds=60`n"
try {
    [Environment]::SetEnvironmentVariable('MODULE9_FAKE_PASSWORD', $canary, 'Process')
    [Environment]::SetEnvironmentVariable('POSTGRES_PASSWORD', $canary, 'Process')
    Invoke-Case 'missing .env' $null $false '.env'
    Invoke-Case 'missing required key' $base $false 'POSTGRES_PASSWORD'
    Invoke-Case 'empty required value' ($base + "POSTGRES_PASSWORD=`n") $false 'POSTGRES_PASSWORD'
    Invoke-Case 'example placeholder' ($base + "POSTGRES_PASSWORD=<set-outside-git>`n") $false 'POSTGRES_PASSWORD'
    Invoke-Case 'valid fake values' ($base + "POSTGRES_PASSWORD=$canary`n") $true ''
    Invoke-Case 'Compose double-quoted interpolation' ($base + 'POSTGRES_PASSWORD="${MODULE9_FAKE_PASSWORD}"' + "`n") $true ''
    Invoke-Case 'optional empty TTL' ("POSTGRES_USER=fixture_user`nPOSTGRES_DB=fixture_db`nASPNETCORE_ENVIRONMENT=Development`nPOSTGRES_PASSWORD=$canary`nCache__TasksTtlSeconds=`n") $false 'Cache__TasksTtlSeconds'
    Write-Output 'Module 9 env preflight smoke passed'
} finally {
    [Environment]::SetEnvironmentVariable('MODULE9_FAKE_PASSWORD', $originalFakePassword, 'Process')
    [Environment]::SetEnvironmentVariable('POSTGRES_PASSWORD', $originalPostgresPassword, 'Process')
    foreach ($path in $fixtures) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    $afterRealEnvHash = if (Test-Path -LiteralPath $realEnv) { (Get-FileHash -Algorithm SHA256 -LiteralPath $realEnv).Hash } else { $null }
    if ($realEnvHash -ne $afterRealEnvHash) { throw 'The real .env changed during fixture tests' }
}
