param(
    [string]$EnvFile = '.env',
    [string]$VolumeName = 'fullstack-ops-postgres-data',
    [string]$ComposeOverrideFile,
    [string]$GrafanaEnvFile
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$requiredKeys = @('POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB', 'ASPNETCORE_ENVIRONMENT',
    'GF_SECURITY_ADMIN_USER', 'GF_SECURITY_ADMIN_PASSWORD')

function Fail([string]$Message) {
    Write-Output $Message
    exit 1
}

function Invoke-Docker([string]$Arguments, [AllowNull()][string]$InputText) {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'docker'
    $start.Arguments = $Arguments
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $true
    foreach ($key in ($requiredKeys + @('Cache__TasksTtlSeconds'))) {
        $start.EnvironmentVariables.Remove($key)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'Docker did not start' }
        if ($null -ne $InputText) { $process.StandardInput.Write($InputText) }
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            $process.WaitForExit()
            throw 'Docker timed out'
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = $stdout.Result
            Stderr = $stderr.Result
        }
    } finally {
        $process.Dispose()
    }
}

try {
    if ($VolumeName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        Fail 'VolumeName must be a valid Docker volume name.'
    }
    $composeArguments = '-f compose.yaml'
    if ($ComposeOverrideFile) {
        $overrideCandidate = if ([System.IO.Path]::IsPathRooted($ComposeOverrideFile)) { $ComposeOverrideFile } else { Join-Path $root $ComposeOverrideFile }
        $override = [System.IO.Path]::GetFullPath($overrideCandidate)
        $prefix = $root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $override.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not [System.IO.File]::Exists($override)) {
            Fail 'ComposeOverrideFile must be an existing file inside the repository.'
        }
        $composeArguments += ' -f "' + $override.Replace('"', '\"') + '"'
    }
    $envFiles = @($EnvFile)
    if ($GrafanaEnvFile) { $envFiles += $GrafanaEnvFile }
    $envArguments = @()
    foreach ($envCandidate in $envFiles) {
        $candidate = if ([System.IO.Path]::IsPathRooted($envCandidate)) { $envCandidate } else { Join-Path $root $envCandidate }
        $file = [System.IO.Path]::GetFullPath($candidate)
        $rootPrefix = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        if (-not $file.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Fail 'EnvFile must be inside the repository.'
        }
        $relative = $file.Substring($rootPrefix.Length).Replace('\', '/')
        if (-not [System.IO.File]::Exists($file)) {
            Fail 'Missing .env file. Copy .env.example to a Git-ignored .env, set local values, and do not commit or share it.'
        }

        & git -C $root check-ignore -q -- $relative 2>$null
        if ($LASTEXITCODE -ne 0) { Fail 'EnvFile is not ignored by Git.' }
        $tracked = & git -C $root ls-files --cached -- $relative 2>$null
        if ($LASTEXITCODE -ne 0) { Fail 'Git could not verify the EnvFile tracking state.' }
        if ($tracked) { Fail 'EnvFile is tracked by Git.' }
        $envArguments += '--env-file "' + $file.Replace('"', '\"') + '"'
    }
    $envArguments = $envArguments -join ' '

    $probe = @'
services:
  preflight:
    image: scratch
    environment:
      POSTGRES_USER: "${POSTGRES_USER-}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD-}"
      POSTGRES_DB: "${POSTGRES_DB-}"
      ASPNETCORE_ENVIRONMENT: "${ASPNETCORE_ENVIRONMENT-}"
      GF_SECURITY_ADMIN_USER: "${GF_SECURITY_ADMIN_USER-}"
      GF_SECURITY_ADMIN_PASSWORD: "${GF_SECURITY_ADMIN_PASSWORD-}"
      Cache__TasksTtlSeconds: "${Cache__TasksTtlSeconds-}"
      Cache__TasksTtlSeconds_IsSet: "${Cache__TasksTtlSeconds+true}"
'@
    $resolved = Invoke-Docker "compose $envArguments -f - config --format json" $probe
    if ($resolved.ExitCode -ne 0) {
        Fail 'Compose could not parse EnvFile. Check its syntax and interpolation without printing resolved config.'
    }
    $values = ($resolved.Stdout | ConvertFrom-Json).services.preflight.environment
    $badKeys = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $requiredKeys) {
        $value = [string]$values.$key
        if ([string]::IsNullOrWhiteSpace($value) -or
            $value -match '^\s*<[^>]+>\s*$' -or
            $value -match '^(?i:CHANGE_ME|REPLACE_ME|PLACEHOLDER|TODO|YOUR[_-].*)$') {
            $badKeys.Add($key)
        }
    }
    if ($values.Cache__TasksTtlSeconds_IsSet -eq 'true') {
        $ttl = 0
        if (-not [int]::TryParse([string]$values.Cache__TasksTtlSeconds, [ref]$ttl) -or $ttl -le 0) {
            $badKeys.Add('Cache__TasksTtlSeconds')
        }
    }
    if ($badKeys.Count -gt 0) {
        Fail ('Missing, empty, placeholder, or invalid keys: ' + ($badKeys -join ', '))
    }
    Write-Output 'Required Compose keys: present and non-placeholder.'

    $config = Invoke-Docker "compose $envArguments $composeArguments config -q" $null
    if ($config.ExitCode -ne 0) {
        Fail 'docker compose config -q failed. Check compose.yaml and local environment; resolved values were not displayed.'
    }
    Write-Output 'docker compose config -q: passed.'

    $volume = Invoke-Docker "volume inspect $volumeName --format {{.Name}}" $null
    if ($volume.ExitCode -ne 0 -or $volume.Stdout.Trim() -ne $volumeName) {
        Fail ('External volume missing or unavailable: ' + $volumeName)
    }
    Write-Output ('External volume exists: ' + $volumeName)
    Write-Output 'Preflight passed. Database credentials and readiness were not verified.'
} catch {
    Fail 'Preflight could not complete. Check Docker/Compose availability and the local file syntax.'
}
