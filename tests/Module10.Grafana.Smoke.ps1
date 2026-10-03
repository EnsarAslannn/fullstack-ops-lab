param(
    [string]$EnvFile = '.env',
    [string]$GrafanaEnvFile,
    [string]$BaseUrl = 'http://127.0.0.1:3000',
    [switch]$EndpointOnly
)
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$compose = @('compose', '--env-file', $EnvFile)
if ($GrafanaEnvFile) { $compose += @('--env-file', $GrafanaEnvFile) }
# Never forward native stderr, response bodies or sensitive exceptions to the terminal.
function Docker([string[]]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = 'docker'
    $info.Arguments = ($Arguments | ForEach-Object {
        '"' + ([regex]::Replace([regex]::Replace($_, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
    }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw 'Docker command could not start' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            throw 'Docker command exceeded 60 seconds'
        }
        $output = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw 'Docker command failed (details withheld)' }
        return $output.Trim()
    } finally { $process.Dispose() }
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw [InvalidOperationException]::new($Message) }
}

function Request([string]$Method, [string]$Path, [object]$Body) {
    $request = [Net.HttpWebRequest]::Create("$BaseUrl$Path")
    $request.Proxy = $null
    $request.Method = $Method
    $request.Timeout = 20000
    if ($null -ne $Body) {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Compress))
        $request.ContentType = 'application/json'
        $request.ContentLength = $bytes.Length
        $stream = $request.GetRequestStream()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    }
    try { $response = $request.GetResponse() }
    catch [Net.WebException] {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw 'HTTP request failed before receiving a response' }
    }
    try {
        $reader = [IO.StreamReader]::new($response.GetResponseStream())
        try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return [pscustomobject]@{
            Status = [int]$response.StatusCode; Body = $content
            Location = $response.Headers['Location']; ContentType = $response.ContentType
        }
    } finally { $response.Close() }
}

try {
    Assert (((Docker ($compose + @('config', '--services'))) -split '\r?\n') -contains 'grafana') 'Grafana service is missing'
    $id = Docker ($compose + @('ps', '-q', 'grafana'))
    Assert (-not [string]::IsNullOrWhiteSpace($id)) 'Grafana service is not running'
    $health = Request 'GET' '/api/health' $null
    Assert ($health.Status -eq 200) 'Grafana health must return 200'
    Assert (($health.Body | ConvertFrom-Json).database -eq 'ok') 'Grafana database must be healthy'
    Assert ((Request 'GET' '/api/datasources' $null).Status -eq 401) 'Anonymous datasource access must be disabled'
    if ($EndpointOnly) { Write-Output 'PASS: Grafana service/health'; exit 0 }
    # Values stay in memory; no credentials in CLI arguments, output or files.
    $envs = (Docker @('inspect', '--format', '{{json .Config.Env}}', $id)) | ConvertFrom-Json
    foreach ($entry in $envs) {
        $key, $value = $entry -split '=',2
        if ($key -eq 'GF_SECURITY_ADMIN_USER') { $user = $value }
        if ($key -eq 'GF_SECURITY_ADMIN_PASSWORD') { $password = $value }
    }
    $credential = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($user + ':' + $password))
    $headers = @{ Authorization = 'Basic ' + $credential }
    $logs = Docker ($compose + @('logs', '--no-color', 'grafana'))
    Assert (-not $logs.Contains($user)) 'Admin username leaked into Grafana logs (value withheld)'
    Assert (-not $logs.Contains($password) -and -not $logs.Contains($credential)) 'Credential leaked into Grafana logs (value withheld)'
    function Grafana([string]$Path) {
        try {
            $data = Invoke-RestMethod -Uri "$BaseUrl$Path" -Headers $headers -TimeoutSec 20
            return $data
        }
        catch { throw 'Authenticated Grafana request failed (details withheld)' }
    }
    $sources = @(Grafana '/api/datasources')
    Assert ($sources.Count -eq 1) 'Expected one provisioned datasource'
    $source = $sources[0]
    Assert ($source.uid -eq 'fullstack-ops-prometheus') 'Datasource UID changed'
    Assert ($source.url -eq 'http://prometheus:9090') 'Datasource must use Compose DNS'
    Assert ($source.type -eq 'prometheus' -and $source.isDefault -and $source.readOnly) 'Datasource provisioning/default/read-only contract failed'
    Assert ((Grafana '/api/datasources/uid/fullstack-ops-prometheus/health').status -eq 'OK') 'Datasource health failed'
    foreach ($expression in @('up{job="fullstack-ops-api"}',
        'http_server_request_duration_seconds_count{job="fullstack-ops-api"}',
        'dotnet_process_memory_working_set_bytes{job="fullstack-ops-api"}',
        'fullstackops_cache_hits_total{job="fullstack-ops-api"}',
        'fullstackops_cache_misses_total{job="fullstack-ops-api"}',
        'fullstackops_cache_invalidations_total{job="fullstack-ops-api"}')) {
        $query = Grafana ('/api/datasources/proxy/uid/fullstack-ops-prometheus/api/v1/query?query=' + [uri]::EscapeDataString($expression))
        Assert ($query.status -eq 'success' -and @($query.data.result).Count -gt 0) "Missing datasource query result: $expression"
        $serialized = $query | ConvertTo-Json -Depth 20 -Compress
        Assert (-not $serialized.Contains($password)) 'Credential leaked into datasource query (value withheld)'
        Write-Output ("PASS: datasource query $expression; series=$(@($query.data.result).Count)")
    }
    # Dashboard provisioning now has its own acceptance test; datasource checks remain reusable.
    Write-Output 'PASS: YAML datasource UID/default/read-only, health, queries and safe logs'
} catch {
    if ($_.Exception -is [InvalidOperationException]) { Write-Output ('FAIL: ' + $_.Exception.Message) }
    else { Write-Output 'FAIL: Grafana acceptance could not complete (details withheld)' }
    exit 1
}
