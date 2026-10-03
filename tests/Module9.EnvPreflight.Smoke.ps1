param(
    [string]$VolumeName = 'fullstack-ops-postgres-data',
    [string]$ComposeOverrideFile
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$preflight = Join-Path $root 'scripts/Module9.EnvPreflight.ps1'
$realEnv = Join-Path $root '.env'
$realEnvHash = if (Test-Path -LiteralPath $realEnv) { (Get-FileHash -Algorithm SHA256 -LiteralPath $realEnv).Hash } else { $null }
$originalFakePassword = [Environment]::GetEnvironmentVariable('MODULE9_FAKE_PASSWORD', 'Process')
$originalPostgresPassword = [Environment]::GetEnvironmentVariable('POSTGRES_PASSWORD', 'Process')
$originalGrafanaPassword = [Environment]::GetEnvironmentVariable('GF_SECURITY_ADMIN_PASSWORD', 'Process')
$canary = 'module9-fixture-' + [guid]::NewGuid().ToString('N')
$fixtures = [System.Collections.Generic.List[string]]::new()

function Invoke-Case([string]$Name, [AllowNull()][string]$Contents,
    [bool]$ShouldPass, [string]$ExpectedKey, [string[]]$ExtraArguments = @()) {
    $ErrorActionPreference = 'Continue'
    $path = Join-Path $root ('.env.module9-fixture-' + [guid]::NewGuid().ToString('N'))
    $fixtures.Add($path)
    if ($Name -ne 'missing .env') {
        [System.IO.File]::WriteAllText($path, $Contents, [System.Text.UTF8Encoding]::new($false))
    }
    $before = if (Test-Path -LiteralPath $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash } else { $null }
    $options = @()
    if ('-VolumeName' -notin $ExtraArguments) { $options += @('-VolumeName', $VolumeName) }
    if ($ComposeOverrideFile -and '-ComposeOverrideFile' -notin $ExtraArguments) {
        $options += @('-ComposeOverrideFile', $ComposeOverrideFile)
    }
    $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File $preflight -EnvFile $path @options @ExtraArguments 2>&1 | Out-String)
    $code = $LASTEXITCODE
    if ($output.Contains($canary)) { throw "$Name leaked the fake password" }
    if ($ShouldPass -and $code -ne 0) { throw "$Name should pass (exit=$code)" }
    if (-not $ShouldPass -and $code -eq 0) { throw "$Name should fail" }
    if ($ExpectedKey -and -not $output.Contains($ExpectedKey)) {
        throw "$Name did not name the problematic key"
    }
    if ($ShouldPass -and -not $output.Contains('External volume exists: ' + $VolumeName)) {
        throw "$Name did not verify the selected volume"
    }
    $after = if (Test-Path -LiteralPath $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash } else { $null }
    if ($before -ne $after) { throw "$Name changed its input file" }
    Write-Output "PASS $Name (exit=$code, canary hidden, fixture unchanged)"
}

$grafana = "GF_SECURITY_ADMIN_USER=fixture_admin`nGF_SECURITY_ADMIN_PASSWORD=$canary`n"
$grafanaPasswordPattern = '(?m)^' + [regex]::Escape('GF_SECURITY_ADMIN_PASSWORD') + '=.*\n'
$base = "POSTGRES_USER=fixture_user`nPOSTGRES_DB=fixture_db`nASPNETCORE_ENVIRONMENT=Development`nCache__TasksTtlSeconds=60`n" + $grafana
try {
    [Environment]::SetEnvironmentVariable('MODULE9_FAKE_PASSWORD', $canary, 'Process')
    [Environment]::SetEnvironmentVariable('POSTGRES_PASSWORD', $canary, 'Process')
    [Environment]::SetEnvironmentVariable('GF_SECURITY_ADMIN_PASSWORD', $canary, 'Process')
    Invoke-Case 'missing Grafana password' (($base -replace $grafanaPasswordPattern, '') + "POSTGRES_PASSWORD=$canary`n") $false 'GF_SECURITY_ADMIN_PASSWORD'
    Invoke-Case 'empty Grafana password' (($base -replace $grafanaPasswordPattern, "GF_SECURITY_ADMIN_PASSWORD=`n") + "POSTGRES_PASSWORD=$canary`n") $false 'GF_SECURITY_ADMIN_PASSWORD'
    Invoke-Case 'placeholder Grafana password' (($base -replace $grafanaPasswordPattern, "GF_SECURITY_ADMIN_PASSWORD=<set-outside-git>`n") + "POSTGRES_PASSWORD=$canary`n") $false 'GF_SECURITY_ADMIN_PASSWORD'
    Invoke-Case 'missing Grafana user' (($base -replace '(?m)^GF_SECURITY_ADMIN_USER=.*\n', '') + "POSTGRES_PASSWORD=$canary`n") $false 'GF_SECURITY_ADMIN_USER'
    Invoke-Case 'empty Grafana user' (($base -replace '(?m)^GF_SECURITY_ADMIN_USER=.*\n', "GF_SECURITY_ADMIN_USER=`n") + "POSTGRES_PASSWORD=$canary`n") $false 'GF_SECURITY_ADMIN_USER'
    Invoke-Case 'placeholder Grafana user' (($base -replace '(?m)^GF_SECURITY_ADMIN_USER=.*\n', "GF_SECURITY_ADMIN_USER=<set-outside-git>`n") + "POSTGRES_PASSWORD=$canary`n") $false 'GF_SECURITY_ADMIN_USER'
    $overlay = Join-Path $root ('.env.module9-fixture-' + [guid]::NewGuid().ToString('N'))
    $fixtures.Add($overlay)
    [IO.File]::WriteAllText($overlay, $grafana, [Text.UTF8Encoding]::new($false))
    $overlayHash = (Get-FileHash -LiteralPath $overlay -Algorithm SHA256).Hash
    $withoutGrafana = ($base -replace '(?m)^GF_SECURITY_ADMIN_(USER|PASSWORD)=.*\n', '') + "POSTGRES_PASSWORD=$canary`n"
    Invoke-Case 'separate ignored Grafana env' $withoutGrafana $true '' @('-GrafanaEnvFile', $overlay)
    if ($overlayHash -ne (Get-FileHash -LiteralPath $overlay -Algorithm SHA256).Hash) { throw 'Grafana overlay was modified' }
    [IO.File]::WriteAllText($overlay, "GF_SECURITY_ADMIN_USER=fixture_admin`nGF_SECURITY_ADMIN_PASSWORD=<set-outside-git>`n", [Text.UTF8Encoding]::new($false))
    Invoke-Case 'placeholder in Grafana overlay' $withoutGrafana $false 'GF_SECURITY_ADMIN_PASSWORD' @('-GrafanaEnvFile', $overlay)
    Invoke-Case 'missing Grafana env file' ($base + "POSTGRES_PASSWORD=$canary`n") $false '.env' @('-GrafanaEnvFile', '.env.module9-missing')
    # Reject an unavailable override before consulting any volume.
    Invoke-Case 'missing Compose override' ($base + "POSTGRES_PASSWORD=$canary`n") $false 'ComposeOverrideFile' @('-ComposeOverrideFile', 'missing-module9-override.yaml')
    Invoke-Case 'invalid volume name' ($base + "POSTGRES_PASSWORD=$canary`n") $false 'VolumeName' @('-VolumeName', 'invalid volume name')
    $missingVolume = 'fullstackops-missing-' + [guid]::NewGuid().ToString('N')
    Invoke-Case 'missing selected volume' ($base + "POSTGRES_PASSWORD=$canary`n") $false $missingVolume @('-VolumeName', $missingVolume)
    Invoke-Case 'missing .env' $null $false '.env'
    Invoke-Case 'missing required key' $base $false 'POSTGRES_PASSWORD'
    Invoke-Case 'empty required value' ($base + "POSTGRES_PASSWORD=`n") $false 'POSTGRES_PASSWORD'
    Invoke-Case 'example placeholder' ($base + "POSTGRES_PASSWORD=<set-outside-git>`n") $false 'POSTGRES_PASSWORD'
    Invoke-Case 'valid fake values' ($base + "POSTGRES_PASSWORD=$canary`n") $true ''
    Invoke-Case 'Compose double-quoted interpolation' ($base + 'POSTGRES_PASSWORD="${MODULE9_FAKE_PASSWORD}"' + "`n") $true ''
    Invoke-Case 'optional empty TTL' (($base -replace 'Cache__TasksTtlSeconds=60', 'Cache__TasksTtlSeconds=') + "POSTGRES_PASSWORD=$canary`n") $false 'Cache__TasksTtlSeconds'
    Write-Output 'Module 9 env preflight smoke passed'
} finally {
    [Environment]::SetEnvironmentVariable('MODULE9_FAKE_PASSWORD', $originalFakePassword, 'Process')
    [Environment]::SetEnvironmentVariable('POSTGRES_PASSWORD', $originalPostgresPassword, 'Process')
    [Environment]::SetEnvironmentVariable('GF_SECURITY_ADMIN_PASSWORD', $originalGrafanaPassword, 'Process')
    foreach ($path in $fixtures) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    $afterRealEnvHash = if (Test-Path -LiteralPath $realEnv) { (Get-FileHash -Algorithm SHA256 -LiteralPath $realEnv).Hash } else { $null }
    if ($realEnvHash -ne $afterRealEnvHash) { throw 'The real .env changed during fixture tests' }
}
