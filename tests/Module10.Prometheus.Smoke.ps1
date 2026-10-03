param(
    [string]$EnvFile = '.env',
    [string]$BaseUrl = 'http://127.0.0.1:18081',
    [string]$PrometheusUrl = 'http://127.0.0.1:9090',
    [switch]$EndpointOnly
)
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$cacheKey = 'fullstack-ops:tasks:all:v1'
$createdId = $null
$cacheTouched = $false
$apiStopped = $false
$redisStopped = $false
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

function Redis([string[]]$Arguments) {
    return Docker (@('compose', '--env-file', $EnvFile, 'exec', '-T', 'redis', 'redis-cli', '--raw') + $Arguments)
}

function Prom([string]$Path) {
    try { $result = Invoke-RestMethod -Uri "$PrometheusUrl$Path" -TimeoutSec 10 }
    catch { throw 'Prometheus HTTP request failed (details withheld)' }
    Assert ($result.status -eq 'success') 'Prometheus query/target API failed'
    return $result.data
}
function Query([string]$Expression) {
    return (Prom ('/api/v1/query?query=' + [uri]::EscapeDataString($Expression))).result
}
function Number([string]$Expression) {
    $result = @(Query $Expression)
    Assert ($result.Count -eq 1) "Expected exactly one sample: $Expression"
    $value = [double]::Parse($result[0].value[1], [Globalization.CultureInfo]::InvariantCulture)
    Assert (-not [double]::IsNaN($value) -and -not [double]::IsInfinity($value)) 'Query has no finite measurement in this window'
    return $value
}
function Target {
    $targets = @((Prom '/api/v1/targets').activeTargets)
    Assert ($targets.Count -eq 1) 'Expected exactly one configured target'
    Assert ($targets[0].scrapeUrl -eq 'http://api:8080/metrics') 'Incorrect scrape URL'
    Assert ($targets[0].scrapeInterval -eq '15s') 'Incorrect scrape interval'
    return $targets[0]
}
function Wait-Scrape([string]$Previous, [string]$Health = 'up') {
    $deadline = [DateTime]::UtcNow.AddSeconds(55)
    do {
        $target = Target
        if ($target.lastScrape -ne $Previous -and $target.health -eq $Health) { return $target.lastScrape }
        Start-Sleep -Seconds 1
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Expected next target scrape did not arrive within 55 seconds'
}
function Wait-Health([string]$Expected) {
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        $health = Docker @('inspect', '--format', '{{.State.Health.Status}}', $script:ApiId)
        if ($health -eq $Expected) { return }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Expected API Docker health status did not arrive within 90 seconds'
}
function Internal-Status([string]$Path) {
    return Docker @('compose', '--env-file', $EnvFile, 'exec', '-T', 'frontend', 'curl',
        '--silent', '--max-time', '15', '--output', '/dev/null', '--write-out', '%{http_code}', "http://api:8080$Path")
}
function Sum([string]$Metric) { return Number "sum($Metric{job=`"fullstack-ops-api`"})" }

try {
    Assert (((Docker @('compose', '--env-file', $EnvFile, 'config', '--services')) -split '\r?\n') -contains 'prometheus') 'Prometheus service is missing'
    $script:ApiId = Docker @('compose', '--env-file', $EnvFile, 'ps', '-q', 'api')
    $promId = Docker @('compose', '--env-file', $EnvFile, 'ps', '-q', 'prometheus')
    Assert (-not [string]::IsNullOrWhiteSpace($promId)) 'Prometheus service is not running'
    $null = Target
    if ($EndpointOnly) { Write-Output 'PASS: Prometheus target endpoint'; exit 0 }
    Assert ((Redis @('EXISTS', $cacheKey)) -eq '0') 'Use an isolated stack without an existing list cache'

    # Create a count sample before comparing subsequent scrapes; no DB mutation.
    Assert ((Request 'POST' '/api/tasks' @{ title = ' ' }).Status -eq 400) 'Warmup validation must return 400'
    $last = Wait-Scrape ((Target).lastScrape)
    $last = Wait-Scrape $last
    Assert ((Number 'up{job="fullstack-ops-api"}') -eq 1) 'Target must be UP'
    Write-Output "Scrape samples in last minute: $(Number 'count_over_time(up{job="fullstack-ops-api"}[1m])')"
    $beforeHttp = Sum 'http_server_request_duration_seconds_count'
    $cacheTouched = $true
    Assert ((Request 'GET' '/api/tasks' $null).Status -eq 200) 'List miss failed'
    Assert ((Request 'GET' '/api/tasks' $null).Status -eq 200) 'List hit failed'
    $post = Request 'POST' '/api/tasks' @{ title = 'module10-prometheus-' + [guid]::NewGuid().ToString('N'); description = $null }
    Assert ($post.Status -eq 201) 'Task creation failed'
    $task = $post.Body | ConvertFrom-Json
    $createdId = $task.id
    Assert ($post.Location -eq "/api/tasks/$createdId") 'Task Location changed'
    Assert (($task.PSObject.Properties.Name | Sort-Object) -join ',' -eq 'createdAt,description,id,isCompleted,title,updatedAt') 'Task JSON contract changed'
    Assert ($null -eq $task.description) 'Nullable description changed'
    Assert ((Request 'GET' "/api/tasks/$createdId" $null).Status -eq 200) 'Task lookup failed'
    Assert ((Request 'PUT' "/api/tasks/$createdId" @{ title = $task.title; description = $null; isCompleted = $true }).Status -eq 200) 'Task update failed'
    Assert ((Request 'DELETE' "/api/tasks/$createdId" $null).Status -eq 204) 'Task delete failed'
    $deletedId = $createdId; $createdId = $null
    Assert ((Request 'POST' '/api/tasks' @{ title = '' }).Status -eq 400) 'Empty title validation changed'
    Assert ((Request 'GET' "/api/tasks/$deletedId" $null).Status -eq 404) 'Deleted Task must return 404'
    $last = Wait-Scrape ((Target).lastScrape)
    Assert (((Sum 'http_server_request_duration_seconds_count') - $beforeHttp) -eq 8) 'Scraped HTTP count must increase by 8'
    Assert ((Sum 'fullstackops_cache_misses_total') -eq 1) 'Scraped miss count must equal 1'
    Assert ((Sum 'fullstackops_cache_hits_total') -eq 1) 'Scraped hit count must equal 1'
    Assert ((Sum 'fullstackops_cache_invalidations_total') -eq 3) 'Scraped invalidation count must equal 3'
    Write-Output 'PASS: CRUD 200/201/200/204, validation 400/404; scraped HTTP +8, miss 1, hit 1, invalidation 3'
    foreach ($metric in @('dotnet_process_cpu_time_seconds_total', 'dotnet_process_memory_working_set_bytes', 'dotnet_gc_heap_total_allocated_bytes_total')) {
        Assert (@(Query "$metric{job=`"fullstack-ops-api`"}").Count -gt 0) "Runtime series missing: $metric"
    }
    # Generate events across scrape boundaries, not just a single cumulative sample.
    Assert ((Request 'GET' '/api/tasks' $null).Status -eq 200) 'Post-mutation miss failed'
    Assert ((Request 'GET' '/api/tasks' $null).Status -eq 200) 'Post-mutation hit failed'
    $last = Wait-Scrape ((Target).lastScrape)
    Write-Output ('Request rate: ' + (Number 'sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api"}[1m]))'))
    Write-Output ('GET-list p95 seconds: ' + (Number 'histogram_quantile(0.95,sum by(le)(rate(http_server_request_duration_seconds_bucket{job="fullstack-ops-api",http_route="/api/tasks/",http_request_method="GET"}[1m])))'))
    Write-Output ('Cache hit ratio: ' + (Number 'sum(rate(fullstackops_cache_hits_total{job="fullstack-ops-api"}[1m])) / (sum(rate(fullstackops_cache_hits_total{job="fullstack-ops-api"}[1m])) + sum(rate(fullstackops_cache_misses_total{job="fullstack-ops-api"}[1m])))'))
    Assert (@(Query 'sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api",http_response_status_code=~"5.."}[1m]))').Count -eq 0) 'Expected no 5xx series before outage'
    Write-Output '5xx rate before outage: empty (no 5xx series), not a measured zero'

    $null = Docker @('compose', '--env-file', $EnvFile, 'stop', 'redis'); $redisStopped = $true
    Wait-Health 'unhealthy'
    Assert ((Internal-Status '/health/live') -eq '200') 'Live must remain 200 during Redis outage'
    Assert ((Internal-Status '/health/ready') -eq '503') 'Ready must return 503 during Redis outage'
    Assert ((Docker @('inspect', '--format', '{{.State.Status}}', $script:ApiId)) -eq 'running') 'API must remain running'
    Assert ((Request 'GET' '/api/tasks' $null).Status -eq 500) 'Redis outage must produce current HTTP 500 behavior'
    $last = Wait-Scrape ((Target).lastScrape)
    Assert ((Number 'up{job="fullstack-ops-api"}') -eq 1) 'Metrics scrape must stay UP during Redis outage'
    Assert ((Request 'GET' '/api/tasks' $null).Status -eq 500) 'Second outage request must return 500'
    $last = Wait-Scrape ((Target).lastScrape)
    Write-Output ('5xx ratio during outage: ' + (Number 'sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api",http_response_status_code=~"5.."}[1m])) / sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api"}[1m]))'))
    Write-Output 'PASS: Redis stopped, API running/unhealthy, live 200, ready 503, two metrics scrapes UP'
    $null = Docker @('compose', '--env-file', $EnvFile, 'start', 'redis'); $redisStopped = $false
    Wait-Health 'healthy'
    Assert ((Internal-Status '/health/ready') -eq '200') 'Readiness did not recover'
    $null = Redis @('DEL', $cacheKey); $cacheTouched = $false

    $null = Docker @('compose', '--env-file', $EnvFile, 'stop', 'api'); $apiStopped = $true
    $last = Wait-Scrape $last 'down'
    Assert ((Number 'up{job="fullstack-ops-api"}') -eq 0) 'Stopped API must produce up=0'
    Write-Output 'PASS: API stopped -> target DOWN/up=0'
    $null = Docker @('compose', '--env-file', $EnvFile, 'start', 'api'); $apiStopped = $false
    Wait-Health 'healthy'
    $last = Wait-Scrape $last
    Assert ((Number 'up{job="fullstack-ops-api"}') -eq 1) 'Restarted API must recover up=1'
    Assert ((Internal-Status '/health/ready') -eq '200') 'Restarted API must be ready'
    Assert ((Docker @('compose', '--env-file', $EnvFile, 'ps', '-q', 'api')) -eq $script:ApiId) 'Expected the same API container'
    $external = Request 'GET' '/metrics' $null
    Assert ($external.ContentType -match 'text/html') 'Nginx must not expose API metrics'
    Write-Output "PASS: same API container healthy, target UP; last scrape $last; external /metrics HTML only"
} catch {
    # Only our fixed assertion messages are safe to show; unexpected exceptions may contain response data.
    if ($_.Exception -is [InvalidOperationException]) { Write-Output ('FAIL: ' + $_.Exception.Message) }
    else { Write-Output 'FAIL: Prometheus acceptance could not complete (details withheld)' }
    exit 1
} finally {
    if ($redisStopped) { $null = Docker @('compose', '--env-file', $EnvFile, 'start', 'redis') }
    if ($apiStopped) { $null = Docker @('compose', '--env-file', $EnvFile, 'start', 'api') }
    if ($null -ne $createdId) { $null = Request 'DELETE' "/api/tasks/$createdId" $null }
    if ($cacheTouched) { $null = Redis @('DEL', $cacheKey) }
}

