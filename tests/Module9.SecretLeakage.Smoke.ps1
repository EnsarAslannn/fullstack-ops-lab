$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scanner = Join-Path $root 'scripts/Module9.SecretLeakage.Check.ps1'
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$canary = 'fixture-secret-' + [guid]::NewGuid().ToString('N')
$tokenCanary = 'ghp_' + [guid]::NewGuid().ToString('N')
$utf8 = [System.Text.UTF8Encoding]::new($false)
$passed = 0

function Write-Fixture([string]$Repository, [string]$RelativePath, [string]$Content) {
    $path = Join-Path $Repository $RelativePath
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $Content, $utf8)
}

function Invoke-Git([string]$Repository, [string[]]$GitArgs) {
    $ErrorActionPreference = 'Continue'
    & git -C $Repository @GitArgs *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Fixture Git setup failed.' }
}

function Invoke-Scanner([string]$Repository) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = 'powershell'
    $info.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $scanner + '" -RepositoryRoot "' + $Repository + '"'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw 'Scanner child did not start.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) {
            $process.Kill()
            throw 'Scanner child timed out.'
        }
        $result = [pscustomobject]@{ Code = $process.ExitCode; Output = $stdout.Result + $stderr.Result }
        if ($result.Output.Contains($canary) -or $result.Output.Contains($tokenCanary)) {
            throw 'Canary appeared in scanner stdout/stderr.'
        }
        return $result
    } finally { $process.Dispose() }
}

function Test-Case([string]$Name, [scriptblock]$Setup, [int]$ExpectedCode,
    [string[]]$ExpectedFindings = @()) {
    $repository = Join-Path $tempRoot ('fullstackops-secret-fixture-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $repository | Out-Null
    try {
        if ($Name -ne 'invalid repository') {
            Invoke-Git $repository @('init', '--quiet')
            Write-Fixture $repository '.gitignore' ".env`n.env.*`n!.env.example`n"
            Invoke-Git $repository @('add', '--', '.gitignore')
        }
        & $Setup $repository
        $result = Invoke-Scanner $repository
        if ($result.Code -ne $ExpectedCode) { throw "$Name returned exit $($result.Code), expected $ExpectedCode." }
        $lines = @($result.Output -split "`r?`n" | Where-Object { $_ })
        if ($ExpectedCode -eq 0 -and $lines.Count -ne 0) { throw "$Name should have no output." }
        if ($ExpectedCode -eq 1) {
            if ($lines.Count -ne $ExpectedFindings.Count) { throw "$Name finding count differs." }
            foreach ($finding in $ExpectedFindings) {
                if ($finding -notin $lines) { throw "$Name lacks an expected path/line/rule finding." }
            }
        }
        if ($ExpectedCode -eq 2 -and ($lines.Count -ne 1 -or $lines[0] -notmatch '^SCAN_ERROR:')) {
            throw "$Name did not report a scan failure safely."
        }
        $script:passed++
        Write-Output "PASS $Name"
    } finally {
        $full = [System.IO.Path]::GetFullPath($repository)
        if (-not $full.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not (Split-Path -Leaf $full).StartsWith('fullstackops-secret-fixture-')) {
            throw 'Fixture cleanup target is outside the expected temporary directory.'
        }
        if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
    }
}

Test-Case 'clean tracked file' {
    param($repo)
    Write-Fixture $repo 'notes.txt' 'No credentials are stored here.'
    Invoke-Git $repo @('add', '--', 'notes.txt')
} 0

Test-Case 'placeholder connection string' {
    param($repo)
    Write-Fixture $repo 'config.txt' 'Host=localhost;Database=sample;Password=<set-outside-git>'
    Invoke-Git $repo @('add', '--', 'config.txt')
} 0

Test-Case 'environment references' {
    param($repo)
    Write-Fixture $repo 'config.txt' 'Host=localhost;Database=sample;Password=${POSTGRES_PASSWORD}'
    Write-Fixture $repo 'code.txt' 'API_KEY=$env:API_KEY'
    Invoke-Git $repo @('add', '--', 'config.txt', 'code.txt')
} 0

Test-Case 'literal connection credential' {
    param($repo)
    Write-Fixture $repo 'config.txt' ("Host=localhost;Database=sample;Password=$canary")
    Invoke-Git $repo @('add', '--', 'config.txt')
} 1 @('config.txt:1:LiteralConnectionCredential')

Test-Case 'password and token assignments' {
    param($repo)
    Write-Fixture $repo 'settings.txt' ("POSTGRES_PASSWORD=$canary`nAPI_KEY=$canary")
    Invoke-Git $repo @('add', '--', 'settings.txt')
} 1 @('settings.txt:1:LiteralCredentialAssignment', 'settings.txt:2:LiteralCredentialAssignment')

Test-Case 'tracked env file' {
    param($repo)
    Write-Fixture $repo '.env' ("POSTGRES_PASSWORD=$canary")
    Invoke-Git $repo @('add', '-f', '--', '.env')
} 1 @('.env:0:EnvFileInGit')

Test-Case 'ignored env file' {
    param($repo)
    Write-Fixture $repo '.env' ("POSTGRES_PASSWORD=$canary")
} 0

Test-Case 'untracked file' {
    param($repo)
    Write-Fixture $repo 'new.txt' ("TOKEN=$canary")
} 1 @('new.txt:1:LiteralCredentialAssignment')

Test-Case 'deleted tracked file' {
    param($repo)
    Write-Fixture $repo 'removed.txt' ("TOKEN=$canary")
    Invoke-Git $repo @('add', '--', 'removed.txt')
    Remove-Item -LiteralPath (Join-Path $repo 'removed.txt')
} 0

Test-Case 'path with spaces' {
    param($repo)
    Write-Fixture $repo 'folder with spaces/config file.txt' ("TOKEN=$canary")
    Invoke-Git $repo @('add', '--', 'folder with spaces/config file.txt')
} 1 @('folder with spaces/config file.txt:1:LiteralCredentialAssignment')

Test-Case 'multiple findings' {
    param($repo)
    Write-Fixture $repo 'multi.txt' ("TOKEN=$canary`nPASSWORD=$canary")
    Invoke-Git $repo @('add', '--', 'multi.txt')
} 1 @('multi.txt:1:LiteralCredentialAssignment', 'multi.txt:2:LiteralCredentialAssignment')

Test-Case 'strong token format' {
    param($repo)
    Write-Fixture $repo 'token.txt' $tokenCanary
    Invoke-Git $repo @('add', '--', 'token.txt')
} 1 @('token.txt:1:TokenFormat')

Test-Case 'private key marker' {
    param($repo)
    Write-Fixture $repo 'key.txt' ('-----BEGIN ' + 'PRIVATE KEY-----')
    Invoke-Git $repo @('add', '--', 'key.txt')
} 1 @('key.txt:1:PrivateKeyBlock')

Test-Case 'invalid UTF-8 read failure' {
    param($repo)
    [System.IO.File]::WriteAllBytes((Join-Path $repo 'bad.txt'), [byte[]]@(0xC3, 0x28))
    Invoke-Git $repo @('add', '--', 'bad.txt')
} 2

Test-Case 'invalid repository' { param($repo) } 2
Write-Output "Module 9 secret leakage smoke passed: $passed cases"
