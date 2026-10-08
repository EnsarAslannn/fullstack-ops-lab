param([string]$Configuration = 'Release', [string]$Scenario)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$apiDirectory = Join-Path $projectRoot 'src/backend/FullStackOpsLab.Api'
$apiDll = Join-Path $apiDirectory "bin/$Configuration/net10.0/FullStackOpsLab.Api.dll"
if (-not (Test-Path $apiDll)) { throw 'Build the API before running this smoke test.' }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Module9ErrorMode {
    [DllImport("kernel32.dll")] public static extern uint GetErrorMode();
    [DllImport("kernel32.dll")] public static extern uint SetErrorMode(uint mode);
}
'@

$canary = 'module9-canary-' + [guid]::NewGuid().ToString('N')
$validPostgres = "Host=127.0.0.1;Port=1;Database=module9;Username=module9;Password=$canary"
$validRedis = '127.0.0.1:1,connectTimeout=1000,connectRetry=0,syncTimeout=1000,abortConnect=false'

function Get-HttpStatus([string]$Url, [int]$TimeoutMs = 20000,
    [string]$Method = 'GET', [string]$Body = '') {
    $request = [System.Net.WebRequest]::Create($Url)
    $request.Proxy = $null
    $request.Timeout = $TimeoutMs
    $request.Method = $Method
    if ($Method -eq 'POST') {
        $request.ContentType = 'application/json'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentLength = $bytes.Length
        $stream = $request.GetRequestStream()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    }
    try {
        $response = $request.GetResponse()
        try { return [int]$response.StatusCode } finally { $response.Close() }
    } catch [System.Net.WebException] {
        if ($null -eq $_.Exception.Response) { throw }
        $response = $_.Exception.Response
        try { return [int]$response.StatusCode } finally { $response.Close() }
    }
}

function Invoke-StartupCase {
    param(
        [string]$Name,
        [AllowNull()][object]$Postgres,
        [AllowNull()][object]$Redis,
        [AllowNull()][object]$Ttl,
        [string]$ErrorKey,
        [bool]$CheckReadiness = $false
    )

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()

    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = 'dotnet'
    $info.Arguments = '"' + $apiDll + '" --urls http://127.0.0.1:' + $port
    $info.WorkingDirectory = $apiDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    foreach ($key in @($info.EnvironmentVariables.Keys)) {
        if ($key -match '^(ConnectionStrings(__|:)|Cache(__|:)TasksTtlSeconds$|ASPNETCORE_|DOTNET_ENVIRONMENT$)') {
            $info.EnvironmentVariables.Remove($key)
        }
    }
    $info.EnvironmentVariables['ASPNETCORE_ENVIRONMENT'] = 'Production'
    $info.EnvironmentVariables['DOTNET_ENVIRONMENT'] = 'Production'
    $info.EnvironmentVariables['Logging__EventLog__LogLevel__Default'] = 'None'
    if ($null -ne $Postgres) { $info.EnvironmentVariables['ConnectionStrings__Postgres'] = $Postgres }
    if ($null -ne $Redis) { $info.EnvironmentVariables['ConnectionStrings__Redis'] = $Redis }
    if ($null -ne $Ttl) { $info.EnvironmentVariables['Cache__TasksTtlSeconds'] = $Ttl }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    $exited = $false
    $exitCode = $null
    $processId = $null
    $health = $null
    $ready = $null
    $invalidTask = $null
    try {
        $previousErrorMode = [Module9ErrorMode]::GetErrorMode()
        try {
            [Module9ErrorMode]::SetErrorMode($previousErrorMode -bor 0x0002) | Out-Null
            if (-not $process.Start()) { throw "$Name could not start the API process" }
        } finally {
            [Module9ErrorMode]::SetErrorMode($previousErrorMode) | Out-Null
        }
        $processId = $process.Id
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $live = $false
        $deadline = (Get-Date).AddSeconds(10)
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
            try {
                $live = (Get-HttpStatus "http://127.0.0.1:$port/health/live" 1000) -eq 200
                if ($live) { break }
            } catch [System.Net.WebException] { }
            Start-Sleep -Milliseconds 100
        }

        $started = $live
        $exited = $process.HasExited
        if ($exited) { $exitCode = $process.ExitCode }

        if ($CheckReadiness) {
            if ($live) {
                $health = Get-HttpStatus "http://127.0.0.1:$port/health"
                $invalidTask = Get-HttpStatus "http://127.0.0.1:$port/api/tasks" 20000 'POST' '{"title":""}'
                try { $ready = Get-HttpStatus "http://127.0.0.1:$port/health/ready" }
                catch [System.Net.WebException] { $ready = $_.Exception.Status.ToString() }
            }
        }
    } finally {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }
        $standardOutput = $stdout.GetAwaiter().GetResult()
        $standardError = $stderr.GetAwaiter().GetResult()
        $process.Dispose()
    }

    if ($standardOutput.Contains($canary) -or $standardError.Contains($canary) -or
        $standardOutput.Contains($validPostgres) -or $standardError.Contains($validPostgres)) {
        throw "$Name leaked the fake credential or a complete connection string"
    }
    if (($Name -eq 'Postgres malformed' -and ($standardOutput + $standardError).Contains('UnknownOption')) -or
        ($Name -eq 'Redis malformed' -and ($standardOutput + $standardError).Contains('connectTimeout'))) {
        throw "$Name exposed a provider parser error"
    }
    if ($ErrorKey -and ($started -or -not $exited -or $exitCode -eq 0)) {
        throw "$Name should exit with a nonzero startup error (pid=$processId, live=$started, exited=$exited, code=$exitCode)"
    }
    if (-not $ErrorKey -and -not $started) {
        throw "$Name should start and return live=200 (pid=$processId, exited=$exited, code=$exitCode)"
    }
    if ($CheckReadiness -and ($health -ne 200 -or $invalidTask -ne 400 -or $ready -ne 503)) {
        throw "$Name expected health=200, invalid Task POST=400 and ready=503; got health=$health task=$invalidTask ready=$ready (pid=$processId)"
    }
    if ($ErrorKey) {
        $expectedStart = if ($ErrorKey -eq 'Cache:TasksTtlSeconds') {
            'Cache:TasksTtlSeconds pozitif bir tams'
        } else {
            "$ErrorKey eksik veya ge"
        }
        if (-not $standardError.Contains($expectedStart)) {
            throw "$Name did not contain the expected safe configuration error on stderr (pid=$processId, code=$exitCode)"
        }
        $exitHex = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$exitCode), 0).ToString('X8')
        Write-Output "PASS $Name (pid=$processId, exit=0x$exitHex, stdoutChars=$($standardOutput.Length), safe stderr message present, canary absent)"
    } else {
        Write-Output "PASS $Name (pid=$processId, health=$health, live=200, invalid-task=$invalidTask, ready=$ready, canary absent)"
    }
}

$cases = @(
    @{ Name = 'Postgres missing'; Postgres = $null; Redis = $validRedis; Ttl = $null; ErrorKey = 'ConnectionStrings:Postgres' },
    @{ Name = 'Postgres empty'; Postgres = ''; Redis = $validRedis; Ttl = $null; ErrorKey = 'ConnectionStrings:Postgres' },
    @{ Name = 'Postgres whitespace'; Postgres = '   '; Redis = $validRedis; Ttl = $null; ErrorKey = 'ConnectionStrings:Postgres' },
    @{ Name = 'Postgres malformed'; Postgres = "$validPostgres;UnknownOption=$canary"; Redis = $validRedis; Ttl = $null; ErrorKey = 'ConnectionStrings:Postgres' },
    @{ Name = 'Postgres host required'; Postgres = 'Database=module9;Username=module9'; Redis = $validRedis; Ttl = $null; ErrorKey = 'ConnectionStrings:Postgres' },
    @{ Name = 'Postgres database required'; Postgres = 'Host=127.0.0.1;Username=module9'; Redis = $validRedis; Ttl = $null; ErrorKey = 'ConnectionStrings:Postgres' },
    @{ Name = 'Postgres user required'; Postgres = 'Host=127.0.0.1;Database=module9'; Redis = $validRedis; Ttl = $null; ErrorKey = 'ConnectionStrings:Postgres' },
    @{ Name = 'Redis missing'; Postgres = $validPostgres; Redis = $null; Ttl = $null; ErrorKey = 'ConnectionStrings:Redis' },
    @{ Name = 'Redis empty'; Postgres = $validPostgres; Redis = ''; Ttl = $null; ErrorKey = 'ConnectionStrings:Redis' },
    @{ Name = 'Redis whitespace'; Postgres = $validPostgres; Redis = '   '; Ttl = $null; ErrorKey = 'ConnectionStrings:Redis' },
    @{ Name = 'Redis malformed'; Postgres = $validPostgres; Redis = "127.0.0.1:1,connectTimeout=$canary"; Ttl = $null; ErrorKey = 'ConnectionStrings:Redis' },
    @{ Name = 'Redis endpoint required'; Postgres = $validPostgres; Redis = 'connectTimeout=1000'; Ttl = $null; ErrorKey = 'ConnectionStrings:Redis' },
    @{ Name = 'TTL empty'; Postgres = $validPostgres; Redis = $validRedis; Ttl = ''; ErrorKey = 'Cache:TasksTtlSeconds' },
    @{ Name = 'TTL noninteger'; Postgres = $validPostgres; Redis = $validRedis; Ttl = 'abc'; ErrorKey = 'Cache:TasksTtlSeconds' },
    @{ Name = 'TTL zero'; Postgres = $validPostgres; Redis = $validRedis; Ttl = '0'; ErrorKey = 'Cache:TasksTtlSeconds' },
    @{ Name = 'TTL negative'; Postgres = $validPostgres; Redis = $validRedis; Ttl = '-1'; ErrorKey = 'Cache:TasksTtlSeconds' },
    @{ Name = 'TTL absent defaults'; Postgres = $validPostgres; Redis = $validRedis; Ttl = $null; ErrorKey = ''; CheckReadiness = $true },
    @{ Name = 'TTL positive'; Postgres = $validPostgres; Redis = $validRedis; Ttl = '120'; ErrorKey = ''; CheckReadiness = $true },
    @{ Name = 'TTL max integer'; Postgres = $validPostgres; Redis = $validRedis; Ttl = '2147483647'; ErrorKey = ''; CheckReadiness = $true },
    @{ Name = 'Postgres password optional'; Postgres = 'Host=127.0.0.1;Port=1;Database=module9;Username=module9'; Redis = $validRedis; Ttl = $null; ErrorKey = ''; CheckReadiness = $true }
)

foreach ($case in $cases) {
    if (-not $Scenario -or $case.Name -eq $Scenario) { Invoke-StartupCase @case }
}
Write-Output 'Module 9 configuration startup smoke passed'
