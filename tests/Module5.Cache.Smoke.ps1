param(
    [string]$BaseUrl = 'http://127.0.0.1:15162',
    [string]$RedisContainer = 'fullstack-ops-redis-lab',
    [string]$PostgresContainer = 'fullstack-ops-postgres-cache-lab',
    [string]$PostgresUser = 'fullstackops',
    [string]$PostgresDatabase = 'fullstackops'
)

$ErrorActionPreference = 'Stop'
$cacheKey = 'fullstack-ops:tasks:all:v1'
$createdId = $null
$postgresStopped = $false

function Send-TaskRequest {
    param([string]$Method, [string]$Path, [object]$RequestBody)

    $options = @{ Uri = "$BaseUrl$Path"; Method = $Method; UseBasicParsing = $true; TimeoutSec = 10 }
    if ($PSVersionTable.PSVersion.Major -ge 7) { $options.SkipHttpErrorCheck = $true }
    if ($PSBoundParameters.ContainsKey('RequestBody')) {
        $options.Body = $RequestBody | ConvertTo-Json -Compress
        $options.ContentType = 'application/json'
    }

    try {
        $response = Invoke-WebRequest @options
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $response.Content; Location = $response.Headers['Location'] }
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $body; Location = $response.Headers['Location'] }
    }
}

function Redis-Cli {
    param([string[]]$RedisArguments)
    $result = @(& docker exec $RedisContainer redis-cli --raw @RedisArguments)
    if ($LASTEXITCODE -ne 0) { throw "redis-cli failed with exit code $LASTEXITCODE." }
    return ($result -join "`n").Trim()
}

function Assert-Status {
    param($Response, [int]$Expected, [string]$Operation)
    if ($Response.Status -ne $Expected) { throw "$Operation expected HTTP $Expected, got $($Response.Status)." }
    Write-Output "$Operation HTTP $Expected"
}

function Assert-CacheKey {
    param([int]$Expected, [string]$Operation)
    $actual = [int](Redis-Cli -RedisArguments @('EXISTS', $cacheKey))
    if ($actual -ne $Expected) { throw "$Operation expected Redis EXISTS=$Expected, got $actual." }
    Write-Output "$Operation Redis EXISTS=$actual"
}

try {
    $null = Redis-Cli -RedisArguments @('DEL', $cacheKey)
    $first = Send-TaskRequest GET '/api/tasks'
    Assert-Status $first 200 'First list (cache miss)'
    if ($first.Body.Trim() -ne '[]') { throw 'This smoke test requires an initially empty tasks list.' }
    Assert-CacheKey 1 'First list should populate empty-list cache'
    $ttl = [int](Redis-Cli -RedisArguments @('TTL', $cacheKey))
    if ($ttl -le 0) { throw "Cache TTL must be positive; got $ttl." }
    Write-Output "Initial cache TTL=$ttl seconds"

    docker stop --time 2 $PostgresContainer | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop PostgreSQL for cache-hit proof.' }
    $postgresStopped = $true
    $hit = Send-TaskRequest GET '/api/tasks'
    Assert-Status $hit 200 'Cached empty list while PostgreSQL is stopped'
    if ($hit.Body.Trim() -ne '[]') { throw 'Cached empty list changed.' }
    docker start $PostgresContainer | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not restart PostgreSQL.' }
    $postgresStopped = $false
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        docker exec $PostgresContainer pg_isready -U $PostgresUser -d $PostgresDatabase | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'PostgreSQL did not become ready after restart.' }
    $reconnected = $false
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        try {
            $probe = Send-TaskRequest GET '/api/tasks/2147483647'
            if ($probe.Status -eq 404) { $reconnected = $true; break }
        } catch [System.Net.WebException] {
            # A stale pooled connection may close the first read after PostgreSQL restarts.
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $reconnected) { throw 'API did not reconnect to PostgreSQL after restart.' }

    $title = "Module 5 cache $([guid]::NewGuid().ToString('N'))"
    $created = Send-TaskRequest POST '/api/tasks' @{ title = $title; description = 'Cache invalidation test' }
    Assert-Status $created 201 'Create task'
    $task = $created.Body | ConvertFrom-Json
    $createdId = [int]$task.id
    if ($created.Location -notlike "*/api/tasks/$createdId") { throw 'Create Location is incorrect.' }
    Assert-CacheKey 0 'POST invalidation'

    $single = Send-TaskRequest GET "/api/tasks/$createdId"
    Assert-Status $single 200 'Get individual task'
    Assert-CacheKey 0 'Individual GET must not populate list cache'

    $afterCreate = Send-TaskRequest GET '/api/tasks'
    Assert-Status $afterCreate 200 'List after POST (cache miss)'
    if (@($afterCreate.Body | ConvertFrom-Json | Where-Object { $_.id -eq $createdId }).Count -ne 1) { throw 'New task missing from list.' }
    Assert-CacheKey 1 'List cached after POST'
    $afterCreateHit = Send-TaskRequest GET '/api/tasks'
    Assert-Status $afterCreateHit 200 'Nonempty list cache hit'
    $freshTask = @($afterCreate.Body | ConvertFrom-Json | Where-Object { $_.id -eq $createdId })[0]
    $cachedTask = @($afterCreateHit.Body | ConvertFrom-Json | Where-Object { $_.id -eq $createdId })[0]
    if ($cachedTask.title -ne $freshTask.title -or $cachedTask.description -ne $freshTask.description -or
        $cachedTask.isCompleted -ne $freshTask.isCompleted -or
        ([DateTimeOffset]$cachedTask.createdAt) -ne ([DateTimeOffset]$freshTask.createdAt) -or
        ([DateTimeOffset]$cachedTask.updatedAt) -ne ([DateTimeOffset]$freshTask.updatedAt)) {
        throw 'Cached DTO fields differ from the PostgreSQL response.'
    }

    $invalid = Send-TaskRequest POST '/api/tasks' @{ title = '   ' }
    Assert-Status $invalid 400 'Invalid POST'
    Assert-CacheKey 1 'Validation must not invalidate cache'
    $missingUpdate = Send-TaskRequest PUT '/api/tasks/2147483647' @{ title = 'Missing'; isCompleted = $true }
    Assert-Status $missingUpdate 404 'Missing PUT'
    Assert-CacheKey 1 'Missing PUT must not invalidate cache'
    $missingDelete = Send-TaskRequest DELETE '/api/tasks/2147483647'
    Assert-Status $missingDelete 404 'Missing DELETE'
    Assert-CacheKey 1 'Missing DELETE must not invalidate cache'

    $updated = Send-TaskRequest PUT "/api/tasks/$createdId" @{ title = $title; description = 'Updated'; isCompleted = $true }
    Assert-Status $updated 200 'Update task'
    Assert-CacheKey 0 'PUT invalidation'
    $afterUpdate = Send-TaskRequest GET '/api/tasks'
    Assert-Status $afterUpdate 200 'List after PUT (cache miss)'
    $updatedInList = @($afterUpdate.Body | ConvertFrom-Json | Where-Object { $_.id -eq $createdId })[0]
    if (-not $updatedInList.isCompleted -or $updatedInList.description -ne 'Updated') { throw 'Updated task missing from list.' }

    $deleted = Send-TaskRequest DELETE "/api/tasks/$createdId"
    Assert-Status $deleted 204 'Delete task'
    $createdId = $null
    Assert-CacheKey 0 'DELETE invalidation'
    $afterDelete = Send-TaskRequest GET '/api/tasks'
    Assert-Status $afterDelete 200 'List after DELETE (cache miss)'
    if ($afterDelete.Body.Trim() -ne '[]') { throw 'Deleted task remains in list.' }
    Assert-CacheKey 1 'Empty list cached after DELETE'

    $remaining = [int](Redis-Cli -RedisArguments @('TTL', $cacheKey))
    if ($remaining -le 0) { throw "Expected positive remaining TTL; got $remaining." }
    Start-Sleep -Seconds ($remaining + 1)
    Assert-CacheKey 0 'Absolute TTL expiration'
    $afterExpiry = Send-TaskRequest GET '/api/tasks'
    Assert-Status $afterExpiry 200 'List after TTL expiration (cache miss)'
    Assert-CacheKey 1 'List re-cached after expiration'
    Write-Output 'Module 5 cache smoke passed.'
} finally {
    if ($postgresStopped) { docker start $PostgresContainer | Out-Null }
    if ($null -ne $createdId) { try { $null = Send-TaskRequest DELETE "/api/tasks/$createdId" } catch { } }
    try { $null = Redis-Cli -RedisArguments @('DEL', $cacheKey) } catch { }
}
