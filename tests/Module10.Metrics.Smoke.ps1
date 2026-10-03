param(
    [string]$EnvFile = '.env',
    [string]$BaseUrl = 'http://127.0.0.1:18081',
    [switch]$EndpointOnly
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
$cacheKey = 'fullstack-ops:tasks:all:v1'
$createdId = $null
$cacheTouched = $false
$redisStopped = $false
$canary = 'module10-task-' + [guid]::NewGuid().ToString('N')
$diagnosticName = 'fullstackops-metrics-probe-' + [guid]::NewGuid().ToString('N')

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
    if (-not $Condition) { throw $Message }
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

function Scrape {
    # A short-lived diagnostic container on the actual Compose network, with no host port.
    $raw = Docker @('run', '--rm', '--name', $diagnosticName, '--network', $script:Network, '--entrypoint', 'curl',
        $script:DiagnosticImage, '--silent', '--show-error', '--max-time', '15', '-i',
        '-H', 'Accept: text/plain;version=0.0.4', 'http://api:8080/metrics')
    Assert ($raw -match '^HTTP/1\.1 200') 'Internal /metrics must return HTTP 200'
    Assert ($raw -match '(?im)^Content-Type: text/plain;.*version=0\.0\.4') 'Expected Prometheus text content type'
    $text = ($raw -split '\r?\n\r?\n', 2)[1]
    Assert ($text -match '(?m)^# TYPE http_server_request_duration_seconds histogram$') 'HTTP histogram is missing'
    Assert (-not $text.Contains($canary)) 'Task canary leaked into metrics (value withheld)'
    foreach ($value in $script:SensitiveValues) {
        Assert (-not $text.Contains($value)) 'Credential leaked into metrics (value withheld)'
    }
    Assert ($text -notmatch 'http_route="/api/tasks/\d') 'Raw Task IDs must not be metric labels'
    foreach ($line in ($text -split '\r?\n' | Where-Object { $_ -match '^http_server_request_duration_seconds[^\n]*\{' })) {
        foreach ($label in [regex]::Matches(($line -split '\{',2)[1], '(?:^|,)([a-z_]+)="')) {
            Assert ($label.Groups[1].Value -in @('otel_scope_name','http_route','http_request_method','http_response_status_code','le')) 'Unexpected HTTP metric label'
        }
    }
    Assert ($text -notmatch '(?m)^(http_server_request_duration_seconds[^\n]*http_route="/(health|metrics))') 'Probe duration samples must be excluded'
    return $text
}

function Sample([string]$Text, [string]$Name, [hashtable]$Labels = @{}) {
    $sum = 0.0
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -notmatch ('^' + [regex]::Escape($Name) + '(\{[^\n]*\})? ([0-9.eE+\-]+)$')) { continue }
        $tags = $Matches[1]
        $value = [double]::Parse($Matches[2], [Globalization.CultureInfo]::InvariantCulture)
        $matchesLabels = $true
        foreach ($key in $Labels.Keys) {
            if ($tags -notmatch ('(?:\{|,)' + [regex]::Escape($key) + '="' + [regex]::Escape([string]$Labels[$key]) + '"(?:,|\})')) {
                $matchesLabels = $false; break
            }
        }
        if ($matchesLabels) { $sum += $value }
    }
    return $sum
}

function Delta([string]$Before, [string]$After, [string]$Name, [int]$Expected, [hashtable]$Labels = @{}) {
    $actual = (Sample $After $Name $Labels) - (Sample $Before $Name $Labels)
    Assert ($actual -eq $Expected) "Unexpected metric delta: $Name (expected $Expected, got $actual)"
}

function Assert-Cache([int]$Expected) {
    Assert ((Redis @('EXISTS', $cacheKey)) -eq [string]$Expected) 'Unexpected Task list cache existence'
}

try {
    $apiId = Docker @('compose', '--env-file', $EnvFile, 'ps', '-q', 'api')
    $frontendId = Docker @('compose', '--env-file', $EnvFile, 'ps', '-q', 'frontend')
    Assert ($apiId.Length -gt 0 -and $frontendId.Length -gt 0) 'Start the four healthy Compose services before this test'
    $networks = (Docker @('inspect', '--format', '{{json .NetworkSettings.Networks}}', $apiId)) | ConvertFrom-Json
    $script:Network = @($networks.PSObject.Properties.Name)[0]
    $script:DiagnosticImage = Docker @('inspect', '--format', '{{.Image}}', $frontendId)
    # Inspect only specific keys privately to check that their values do not appear in metrics.
    $apiEnv = (Docker @('inspect', '--format', '{{json .Config.Env}}', $apiId)) | ConvertFrom-Json
    $pgId = Docker @('compose', '--env-file', $EnvFile, 'ps', '-q', 'postgres')
    $pgEnv = (Docker @('inspect', '--format', '{{json .Config.Env}}', $pgId)) | ConvertFrom-Json
    $script:SensitiveValues = @(@($apiEnv) + @($pgEnv) | Where-Object {
        $_ -match '^(ConnectionStrings__Postgres|POSTGRES_PASSWORD)='
    } | ForEach-Object { ($_ -split '=', 2)[1] } | Where-Object { $_.Length -gt 0 })
    # Instruments publish a series only after a measurement. Warm up without writing data.
    $warmup = Request POST '/api/tasks' @{ title='' }
    Assert ($warmup.Status -eq 400) 'HTTP metric warmup must reject an empty title'
    $before = Scrape
    Write-Output 'Internal /metrics: HTTP 200, Prometheus text histogram, secret/canary check PASS'
    if ($EndpointOnly) { exit 0 }
    Write-Output ("Baseline: HTTP count={0}; cache hits={1}, misses={2}, invalidations={3}" -f
        (Sample $before 'http_server_request_duration_seconds_count'),
        (Sample $before 'fullstackops_cache_hits_total'),
        (Sample $before 'fullstackops_cache_misses_total'),
        (Sample $before 'fullstackops_cache_invalidations_total'))

    Assert ((Docker @('inspect', '--format', '{{json .HostConfig.PortBindings}}', $apiId)) -eq '{}') 'API must not publish host ports'
    $public = Request GET '/metrics'
    Assert ($public.Status -eq 200 -and $public.ContentType -match 'text/html' -and
        $public.Body -notmatch '# TYPE http_server_request_duration') 'Frontend /metrics must be SPA HTML, not metric content'
    foreach ($name in @('dotnet_process_cpu_time_seconds_total', 'dotnet_process_memory_working_set_bytes',
        'dotnet_gc_heap_total_allocated_bytes_total', 'dotnet_thread_pool_thread_count_total')) {
        Assert ($before -match ('(?m)^' + [regex]::Escape($name) + '(\{| )')) "Runtime metric is missing: $name"
    }
    Assert-Cache 0
    $cacheTouched = $true
    $null = Redis @('DEL', $cacheKey)
    $miss = Request GET '/api/tasks'
    Assert ($miss.Status -eq 200) 'List miss should return 200'
    Assert-Cache 1
    $ttl = [int](Redis @('TTL', $cacheKey))
    $configuredTtl = 60
    foreach ($entry in $apiEnv) { if ($entry -match '^Cache__TasksTtlSeconds=(\d+)$') { $configuredTtl = [int]$Matches[1] } }
    Assert ($ttl -gt 0 -and $ttl -le $configuredTtl -and $ttl -ge ($configuredTtl - 5)) 'Redis TTL differs from configuration'
    $hit = Request GET '/api/tasks'
    Assert ($hit.Status -eq 200 -and $hit.Body -eq $miss.Body) 'List hit must preserve DTOs'
    $afterList = Scrape
    Delta $before $afterList 'fullstackops_cache_misses_total' 1
    Delta $before $afterList 'fullstackops_cache_hits_total' 1
    Delta $before $afterList 'http_server_request_duration_seconds_count' 2 @{ http_route='/api/tasks/'; http_request_method='GET'; http_response_status_code='200' }
    Write-Output 'Initial controlled GET pair: HTTP count +2, cache miss +1, cache hit +1'
    # Preserve database rows: seed only the test-owned cache to exercise the empty-hit branch.
    $null = Redis @('HSET', $cacheKey, 'data', '[]')
    $empty = Request GET '/api/tasks'
    Assert ($empty.Status -eq 200 -and $empty.Body.Trim() -eq '[]') 'Cached empty array must return 200/[]'
    $afterEmpty = Scrape
    Delta $afterList $afterEmpty 'fullstackops_cache_hits_total' 1
    Delta $afterList $afterEmpty 'fullstackops_cache_misses_total' 0
    $null = Redis @('DEL', $cacheKey)

    $created = Request POST '/api/tasks' @{ title=$canary; description=$null }
    Assert ($created.Status -eq 201) 'POST must return 201'
    $task = $created.Body | ConvertFrom-Json
    $createdId = [int]$task.id
    Assert ($created.Location -eq "/api/tasks/$createdId") 'POST Location must identify the created Task'
    Assert ((@($task.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'createdAt,description,id,isCompleted,title,updatedAt') 'Six-field contract changed'
    Assert ($null -eq $task.description -and -not $task.isCompleted) 'Nullable description/default completion changed'
    Assert-Cache 0
    $single = Request GET "/api/tasks/$createdId"
    Assert ($single.Status -eq 200) 'Individual GET must return 200'
    $null = Request GET '/api/tasks'
    $invalid = Request POST '/api/tasks' @{ title='   ' }
    Assert ($invalid.Status -eq 400) 'Blank title must return 400'
    $missing = Request GET '/api/tasks/2147483647'
    Assert ($missing.Status -eq 404) 'Missing ID must return 404'
    $missingPut = Request PUT '/api/tasks/2147483647' @{ title='missing'; isCompleted=$true }
    $missingDelete = Request DELETE '/api/tasks/2147483647'
    Assert ($missingPut.Status -eq 404 -and $missingDelete.Status -eq 404) 'Missing mutations must return 404'
    Assert-Cache 1
    $afterInvalid = Scrape
    Delta $afterEmpty $afterInvalid 'fullstackops_cache_invalidations_total' 1
    $updated = Request PUT "/api/tasks/$createdId" @{ title=$canary; description=$null; isCompleted=$true }
    Assert ($updated.Status -eq 200 -and ($updated.Body | ConvertFrom-Json).isCompleted) 'PUT should complete the Task'
    Assert-Cache 0
    $null = Request GET '/api/tasks'
    $deleted = Request DELETE "/api/tasks/$createdId"
    Assert ($deleted.Status -eq 204) 'DELETE must return 204'
    $createdId = $null
    Assert-Cache 0
    $afterCrud = Scrape
    Delta $afterInvalid $afterCrud 'fullstackops_cache_invalidations_total' 2
    foreach ($case in @(
        @('POST','/api/tasks/','201',1), @('POST','/api/tasks/','400',1),
        @('GET','/api/tasks/{id:int}','200',1), @('GET','/api/tasks/{id:int}','404',1),
        @('PUT','/api/tasks/{id:int}','200',1), @('PUT','/api/tasks/{id:int}','404',1),
        @('DELETE','/api/tasks/{id:int}','204',1), @('DELETE','/api/tasks/{id:int}','404',1)
    )) {
        Delta $before $afterCrud 'http_server_request_duration_seconds_count' $case[3] @{
            http_request_method=$case[0]; http_route=$case[1]; http_response_status_code=$case[2]
        }
    }
    $taskLabels = @{ http_route='/api/tasks/' }
    $durationDelta = (Sample $afterCrud 'http_server_request_duration_seconds_sum' $taskLabels) -
        (Sample $before 'http_server_request_duration_seconds_sum' $taskLabels)
    Assert ($durationDelta -gt 0) 'Histogram duration sum must increase'
    Delta $before $afterCrud 'http_server_request_duration_seconds_bucket' 7 @{ http_route='/api/tasks/'; le='+Inf' }
    Delta $before $afterCrud 'http_server_request_duration_seconds_count' 13
    Delta $before $afterCrud 'fullstackops_cache_misses_total' 3
    Delta $before $afterCrud 'fullstackops_cache_hits_total' 2
    Write-Output 'Main controlled window: HTTP histogram count +13; list-route +Inf bucket +7; cache misses +3, hits +2, invalidations +3'
    Write-Output ('List-route histogram sum delta={0} seconds' -f $durationDelta.ToString('G9', [Globalization.CultureInfo]::InvariantCulture))
    Write-Output "HTTP count/status/template/bucket/sum PASS; cache miss/hit/empty-hit and 3 invalidations PASS; Redis TTL=$ttl/$configuredTtl seconds"

    $expiryList = Request GET '/api/tasks'
    Assert ($expiryList.Status -eq 200) 'List before cache expiry should return 200'
    Assert-Cache 1
    $expiryDeadline = (Get-Date).AddSeconds(120)
    do {
        $exists = Redis @('EXISTS', $cacheKey)
        if ($exists -eq '0') { break }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $expiryDeadline)
    Assert ($exists -eq '0') 'Cache did not expire within 120 seconds; use a short lab TTL for this smoke test'
    $afterExpiry = Request GET '/api/tasks'
    Assert ($afterExpiry.Status -eq 200 -and $afterExpiry.Body -eq $expiryList.Body) 'Expired cache must reload the same database DTOs'
    Assert-Cache 1
    $expiryMetrics = Scrape
    Delta $afterCrud $expiryMetrics 'fullstackops_cache_misses_total' 2
    Delta $afterCrud $expiryMetrics 'fullstackops_cache_hits_total' 0
    $afterCrud = $expiryMetrics
    Write-Output 'Real cache TTL expiration and re-population PASS (two additional misses)'

    # Failed reads are not misses or hits. Existing failure policy must still return 500.
    $redisStopped = $true
    $null = Docker @('compose','--env-file',$EnvFile,'stop','redis')
    $failedList = Request GET '/api/tasks'
    Assert ($failedList.Status -eq 500) 'Redis failure must preserve HTTP 500 behavior'
    $afterFailure = Scrape
    Delta $afterCrud $afterFailure 'fullstackops_cache_hits_total' 0
    Delta $afterCrud $afterFailure 'fullstackops_cache_misses_total' 0
    Delta $afterCrud $afterFailure 'fullstackops_cache_invalidations_total' 0
    Delta $afterCrud $afterFailure 'http_server_request_duration_seconds_count' 1 @{ http_route='/api/tasks/'; http_response_status_code='500' }
    $failedInvalidation = Request POST '/api/tasks' @{ title=$canary; description=$null }
    Assert ($failedInvalidation.Status -eq 201) 'Successful database write must survive invalidation failure'
    $createdId = [int]($failedInvalidation.Body | ConvertFrom-Json).id
    $afterFailedInvalidation = Scrape
    Delta $afterFailure $afterFailedInvalidation 'fullstackops_cache_invalidations_total' 0
    Write-Output 'Failed Redis read/invalidation not counted as success; HTTP 500/201 policy PASS'
    Write-Output 'Runtime metrics, internal-only exposure, six-field/nullable CRUD and secret/canary checks PASS'
} finally {
    if ($redisStopped) {
        $null = Docker @('compose','--env-file',$EnvFile,'start','redis')
        Start-Sleep -Seconds 2
    }
    if ($null -ne $createdId) {
        $cleanup = Request DELETE "/api/tasks/$createdId"
        Assert ($cleanup.Status -eq 204) 'Test Task cleanup failed'
    }
    if ($cacheTouched) { $null = Redis @('DEL', $cacheKey) }
    $remainingDiagnostic = Docker @('ps','-aq','--filter',"name=^/$diagnosticName$")
    if ($remainingDiagnostic.Length -gt 0) { $null = Docker @('rm','-f',$remainingDiagnostic) }
}
