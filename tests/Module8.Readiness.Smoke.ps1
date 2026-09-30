param([string]$EnvFile = '.env')

$ErrorActionPreference = 'Stop'

function Get-ApiStatus([string]$Path) {
    $status = docker compose --env-file $EnvFile exec -T frontend curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 12 "http://api:8080$Path"
    if ($LASTEXITCODE -ne 0) { throw "GET $Path failed before receiving an HTTP response" }
    return $status.Trim()
}

function Assert-ApiStatus([string]$Path, [string]$Expected) {
    $actual = Get-ApiStatus $Path
    if ($actual -ne $Expected) { throw "GET $Path expected HTTP $Expected, got $actual" }
}

function Wait-ForApiHealth([string]$Expected) {
    $apiId = docker compose --env-file $EnvFile ps -q api
    if ($LASTEXITCODE -ne 0 -or -not $apiId) { throw 'API container is missing' }
    $deadline = (Get-Date).AddSeconds(50)
    do {
        $actual = docker inspect --format '{{.State.Health.Status}}' $apiId
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect API health' }
        if ($actual.Trim() -eq $Expected) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "API Docker health did not become $Expected (last: $actual)"
}

function Assert-ApiRunning {
    $apiId = docker compose --env-file $EnvFile ps -q api
    if ($LASTEXITCODE -ne 0 -or $apiId -ne $script:OriginalApiId) {
        throw 'API container was replaced during the outage'
    }
    $state = docker inspect --format '{{.State.Status}}' $apiId
    if ($LASTEXITCODE -ne 0 -or $state.Trim() -ne 'running') {
        throw "API container should still be running (state: $state)"
    }
}

function Clear-TaskCache {
    docker compose --env-file $EnvFile exec -T redis redis-cli DEL fullstack-ops:tasks:all:v1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not clear the Task list cache key' }
}

function Wait-ForReady {
    $deadline = (Get-Date).AddSeconds(50)
    do {
        if ((Get-ApiStatus '/health/ready') -eq '200') { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw 'API readiness did not recover in 50 seconds'
}

function Check-Ready {
    Assert-ApiStatus '/health' '200'
    Assert-ApiStatus '/health/live' '200'
    Assert-ApiStatus '/health/ready' '200'
    Wait-ForApiHealth 'healthy'
}

function Wait-ForAllServicesHealthy {
    $deadline = (Get-Date).AddSeconds(50)
    do {
        $states = @(docker compose --env-file $EnvFile ps --format '{{.Service}}|{{.State}}|{{.Health}}')
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Compose services' }
        $notHealthy = @($states | Where-Object { $_ -notmatch '^(api|frontend|postgres|redis)\|running\|healthy$' })
        if ($states.Count -eq 4 -and $notHealthy.Count -eq 0) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Four Compose services did not become healthy (last: $($states -join ', '))"
}

function Check-Outage([string]$Service) {
    try {
        docker compose --env-file $EnvFile stop $Service | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not stop $Service" }
        Assert-ApiRunning
        Assert-ApiStatus '/health' '200'
        Assert-ApiStatus '/health/live' '200'
        Assert-ApiStatus '/health/ready' '503'
        Wait-ForApiHealth 'unhealthy'
        Assert-ApiStatus '/api/tasks' '500'
        Write-Output "$Service stopped: API running, live=200, ready=503, Docker health=unhealthy, tasks=500"
    } finally {
        docker compose --env-file $EnvFile start $Service | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not restore $Service" }
        Wait-ForReady
        Wait-ForApiHealth 'healthy'
    }
    Check-Ready
    Assert-ApiStatus '/api/tasks' '200'
    Write-Output "$Service restored: same API container, ready=200, Docker health=healthy, tasks=200"
}

$script:OriginalApiId = docker compose --env-file $EnvFile ps -q api
if ($LASTEXITCODE -ne 0 -or -not $script:OriginalApiId) { throw 'API container is missing' }
Check-Ready
Wait-ForAllServicesHealthy
Write-Output 'Both dependencies available: live=200, ready=200, API Docker health=healthy'
Check-Outage 'redis'
Clear-TaskCache
Check-Outage 'postgres'
Clear-TaskCache
Wait-ForAllServicesHealthy
Write-Output 'Module 8 readiness smoke test passed'
