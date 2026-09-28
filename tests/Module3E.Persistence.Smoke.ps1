param(
    [int]$Port = 15162
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$apiDirectory = Join-Path $repositoryRoot 'src/backend/FullStackOpsLab.Api'
$apiDll = Join-Path $apiDirectory 'bin/Release/net10.0/FullStackOpsLab.Api.dll'
$baseUrl = "http://127.0.0.1:$Port"
$originalEnvironment = $env:ASPNETCORE_ENVIRONMENT
$apiProcess = $null
$taskId = $null

function Start-TestApi {
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $script:apiProcess = Start-Process -FilePath 'dotnet' -ArgumentList @("`"$apiDll`"", '--urls', $baseUrl) `
        -WorkingDirectory $apiDirectory -WindowStyle Hidden -PassThru

    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        if ($script:apiProcess.HasExited) { throw 'Test API process exited before /health was ready.' }
        try {
            $health = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec 1
            if ($health.StatusCode -eq 200) { return }
        } catch [System.Net.WebException] {
            Start-Sleep -Milliseconds 200
        }
    }

    throw 'Test API did not become healthy within 10 seconds.'
}

function Stop-TestApi {
    if ($null -ne $script:apiProcess) {
        if (-not $script:apiProcess.HasExited) {
            Stop-Process -Id $script:apiProcess.Id -Force
            $script:apiProcess.WaitForExit()
        }
        $script:apiProcess = $null
    }
}

function Send-TaskRequest {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [string]$Path,
        [object]$RequestBody
    )

    $options = @{ Uri = "$baseUrl$Path"; Method = $Method; UseBasicParsing = $true }
    if ($PSBoundParameters.ContainsKey('RequestBody')) {
        $options.Body = $RequestBody | ConvertTo-Json -Compress
        $options.ContentType = 'application/json'
    }

    try {
        $response = Invoke-WebRequest @options
        return [pscustomobject]@{
            Status = [int]$response.StatusCode
            Body = $response.Content
            Location = $response.Headers['Location']
        }
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return [pscustomobject]@{
            Status = [int]$response.StatusCode
            Body = $body
            Location = $response.Headers['Location']
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $apiDll)) { throw 'Build the API in Release before running this test.' }
    $portCheck = [System.Net.Sockets.TcpClient]::new()
    try {
        $portCheck.Connect('127.0.0.1', $Port)
        throw "Test port $Port is already in use."
    } catch [System.Net.Sockets.SocketException] {
        # Connection refused means this test can own the port.
    } finally {
        $portCheck.Dispose()
    }

    Start-TestApi
    $title = "Module 3E persistence $([guid]::NewGuid().ToString('N'))"
    $created = Send-TaskRequest POST '/api/tasks' @{ title = $title; description = 'API restart test' }
    if ($created.Status -ne 201) { throw "Create expected HTTP 201; got $($created.Status)." }
    $task = $created.Body | ConvertFrom-Json
    if ($task.id -le 0 -or $task.title -ne $title -or $created.Location -notlike "*/api/tasks/$($task.id)") {
        throw 'Create returned an invalid task or Location.'
    }
    $taskId = $task.id

    $updated = Send-TaskRequest PUT "/api/tasks/$taskId" @{
        title = $title
        description = 'Updated before API restart'
        isCompleted = $true
    }
    if ($updated.Status -ne 200) { throw "Update expected HTTP 200; got $($updated.Status)." }
    $task = $updated.Body | ConvertFrom-Json
    if ($task.description -ne 'Updated before API restart' -or $task.isCompleted -ne $true) {
        throw 'Update returned incorrect fields.'
    }

    Stop-TestApi
    Start-TestApi

    $fetched = Send-TaskRequest GET "/api/tasks/$taskId"
    if ($fetched.Status -ne 200) {
        throw "Persistence after API restart expected HTTP 200; got $($fetched.Status)."
    }

    $persisted = $fetched.Body | ConvertFrom-Json
    if ($persisted.id -ne $task.id -or $persisted.title -ne $task.title -or
        $persisted.description -ne $task.description -or $persisted.isCompleted -ne $task.isCompleted -or
        ([DateTimeOffset]$persisted.createdAt) -ne ([DateTimeOffset]$task.createdAt) -or
        ([DateTimeOffset]$persisted.updatedAt) -ne ([DateTimeOffset]$task.updatedAt)) {
        throw "Task fields changed after API restart: createdAt $($task.createdAt) -> $($persisted.createdAt); updatedAt $($task.updatedAt) -> $($persisted.updatedAt)."
    }

    $deleted = Send-TaskRequest DELETE "/api/tasks/$taskId"
    if ($deleted.Status -ne 204) { throw "Test task cleanup expected HTTP 204; got $($deleted.Status)." }
    Write-Output "Module 3E persistence smoke passed: task $taskId survived API restart and was deleted."
    $taskId = $null
} finally {
    if ($null -ne $taskId -and $null -ne $apiProcess -and -not $apiProcess.HasExited) {
        try { $null = Send-TaskRequest DELETE "/api/tasks/$taskId" } catch { }
    }
    Stop-TestApi
    $env:ASPNETCORE_ENVIRONMENT = $originalEnvironment
}
