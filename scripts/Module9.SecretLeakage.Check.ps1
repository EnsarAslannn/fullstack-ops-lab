param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$credentialKey = '(?:POSTGRES_PASSWORD|REDIS_PASSWORD|GF_SECURITY_ADMIN_PASSWORD|CLIENT_SECRET|API[_-]?KEY|ACCESS_TOKEN|AUTH_TOKEN|BEARER_TOKEN|PASSWORD|PWD|TOKEN)'
$valuePattern = '(?<value>"[^"\r\n]*"|''[^''\r\n]*''|[^\s;,#]+)'
$equalsAssignment = [regex]::new('(?i)(?<![A-Za-z0-9_])' + $credentialKey + '\s*=\s*' + $valuePattern)
$colonAssignment = [regex]::new('(?i)^\s*["'']?' + $credentialKey + '["'']?\s*:\s*' + $valuePattern)
$connectionPassword = [regex]::new('(?i)\b(?:Password|Pwd)\s*=\s*' + $valuePattern)
$connectionHost = [regex]::new('(?i)\b(?:Host|Server|Data Source|DataSource)\s*=')
$strongToken = [regex]::new('(?:\bghp_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{30,}\b|\bAKIA[0-9A-Z]{16}\b|\bsk-[A-Za-z0-9]{32,}\b)')
$privateKey = [regex]::new('-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----')

function Invoke-Git([string]$Root, [string]$Command) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = 'git'
    $info.Arguments = '-C "' + $Root.Replace('"', '\"') + '" ' + $Command
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = $utf8
    $info.StandardErrorEncoding = $utf8
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw 'Git did not start' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) {
            $process.Kill()
            throw 'Git timed out'
        }
        if ($process.ExitCode -ne 0) { throw 'Git command failed' }
        return $stdout.Result
    } finally { $process.Dispose() }
}

function Is-ReferenceOrExample([string]$RawValue) {
    $value = $RawValue.Trim().Trim('"', "'").Trim()
    if (-not $value) { return $true }
    if ($value -eq '`') { return $true } # Markdown inline `Password=` has no value.
    # An empty PowerShell fixture may express the following newline as `n or `r`n.
    if ($value.StartsWith('`n') -or $value.StartsWith('`r`n')) { return $true }
    if ($value.StartsWith('$') -or $value.StartsWith('%') -or
        $value.StartsWith('<') -or $value.StartsWith('{{')) { return $true }
    if ($value -match '^(?i:(?:CHANGE[_-]?ME|REPLACE[_-]?ME|YOUR[_-].*|PLACEHOLDER|EXAMPLE(?:[_-].*)?|SAMPLE(?:[_-].*)?|FAKE(?:[_-].*)?|TEST(?:[_-].*)?|null|none))$') {
        return $true
    }
    return $false
}

function Add-Finding([string]$Path, [int]$Line, [string]$Rule) {
    $script:findings.Add(('{0}:{1}:{2}' -f $Path, $Line, $Rule))
}

try {
    $root = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    if (-not [System.IO.Directory]::Exists($root)) { throw 'Repository missing' }
    $topLevel = (Invoke-Git $root 'rev-parse --show-toplevel').Trim()
    if (-not [string]::Equals([System.IO.Path]::GetFullPath($topLevel).TrimEnd('\', '/'),
        $root, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Not a repository root' }

    # NUL-delimited Git paths preserve spaces and newlines. Ignored untracked files never enter this list.
    $tracked = @( (Invoke-Git $root 'ls-files -z --cached').Split([char]0) | Where-Object { $_ })
    $newFiles = @( (Invoke-Git $root 'ls-files -z --others --exclude-standard').Split([char]0) | Where-Object { $_ })
    $findings = [System.Collections.Generic.List[string]]::new()
    $rootPrefix = $root + [System.IO.Path]::DirectorySeparatorChar
    foreach ($relative in ($tracked + $newFiles)) {
        $displayPath = $relative.Replace('\', '/').Replace("`r", '\r').Replace("`n", '\n')
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Git path outside repository'
        }
        if (-not [System.IO.File]::Exists($fullPath)) { continue } # deleted tracked file
        $name = [System.IO.Path]::GetFileName($fullPath)
        if ($name -match '^(?i)\.env(?:\..+)?$' -and $name -ine '.env.example') {
            Add-Finding $displayPath 0 'EnvFileInGit'
            continue # never read a real env file, even if it was force-added
        }
        if (([System.IO.File]::GetAttributes($fullPath) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Symbolic link is outside the text scanner scope'
        }
        $bytes = [System.IO.File]::ReadAllBytes($fullPath)
        if ([Array]::IndexOf($bytes, [byte]0) -ge 0) { throw 'Binary file is outside the text scanner scope' }
        $content = $utf8.GetString($bytes).TrimStart([char]0xFEFF)
        $lines = $content -split "`r`n|`n|`r"
        for ($index = 0; $index -lt $lines.Length; $index++) {
            $line = $lines[$index]
            $number = $index + 1
            if ($privateKey.IsMatch($line)) { Add-Finding $displayPath $number 'PrivateKeyBlock' }
            if ($strongToken.IsMatch($line)) { Add-Finding $displayPath $number 'TokenFormat' }

            $connection = $connectionHost.IsMatch($line) -and $connectionPassword.IsMatch($line)
            if ($connection) {
                $passwordMatch = $connectionPassword.Match($line)
                if (-not (Is-ReferenceOrExample $passwordMatch.Groups['value'].Value)) {
                    Add-Finding $displayPath $number 'LiteralConnectionCredential'
                }
            }
            if (-not $connection) {
                $assignment = $equalsAssignment.Match($line)
                if (-not $assignment.Success) { $assignment = $colonAssignment.Match($line) }
                if ($assignment.Success -and
                    -not (Is-ReferenceOrExample $assignment.Groups['value'].Value)) {
                    Add-Finding $displayPath $number 'LiteralCredentialAssignment'
                }
            }
        }
    }
    foreach ($finding in $findings) { Write-Output $finding }
    if ($findings.Count -gt 0) { exit 1 }
    exit 0
} catch {
    # Exception text and file contents may include credentials. Only a fixed error is safe.
    Write-Output 'SCAN_ERROR: repository inventory or text scan could not complete.'
    exit 2
}
