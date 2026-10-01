param(
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$volumeName = 'fullstack-ops-postgres-data'
$requiredKeys = @('POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB', 'ASPNETCORE_ENVIRONMENT')

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
    # A shell variable must not conceal a missing or placeholder value in this file.
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
    $candidate = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $root $EnvFile }
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

    # Compose itself parses .env quoting/interpolation. The resolved JSON stays in memory.
    $probe = @'
services:
  preflight:
    image: scratch
    environment:
      POSTGRES_USER: "${POSTGRES_USER-}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD-}"
      POSTGRES_DB: "${POSTGRES_DB-}"
      ASPNETCORE_ENVIRONMENT: "${ASPNETCORE_ENVIRONMENT-}"
      Cache__TasksTtlSeconds: "${Cache__TasksTtlSeconds-}"
      Cache__TasksTtlSeconds_IsSet: "${Cache__TasksTtlSeconds+true}"
'@
    $quotedFile = '"' + $file.Replace('"', '\"') + '"'
    $resolved = Invoke-Docker "compose --env-file $quotedFile -f - config --format json" $probe
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

    $config = Invoke-Docker "compose --env-file $quotedFile -f compose.yaml config -q" $null
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
    # Docker, Git, and parser errors can contain resolved values. Never echo exceptions.
    Fail 'Preflight could not complete. Check Docker/Compose availability and the local file syntax.'
}
