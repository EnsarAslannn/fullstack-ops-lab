param(
    [string]$BaseUrl = 'http://localhost:5162'
)

$ErrorActionPreference = 'Stop'

function Send-TaskRequest {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [string]$Path,
        [object]$RequestBody
    )

    $options = @{
        Uri = "$BaseUrl$Path"
        Method = $Method
        UseBasicParsing = $true
    }

    if ($PSBoundParameters.ContainsKey('RequestBody')) {
        $options.Body = $RequestBody | ConvertTo-Json -Compress
        $options.ContentType = 'application/json'
    }

    try {
        $response = Invoke-WebRequest @options
        return [pscustomobject]@{
            Status = [int]$response.StatusCode
            Body = $response.Content
            Headers = $response.Headers
        }
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return [pscustomobject]@{
            Status = [int]$response.StatusCode
            Body = $body
            Headers = $response.Headers
        }
    }
}

function Assert-Status {
    param([object]$Response, [int]$Expected, [string]$Scenario)
    if ($Response.Status -ne $Expected) {
        throw "$Scenario expected HTTP $Expected; got $($Response.Status): $($Response.Body)"
    }
}

$list = Send-TaskRequest GET '/api/tasks'
Assert-Status $list 200 'List tasks'
if ($list.Body -notmatch '^\s*\[') { throw 'GET /api/tasks should return a JSON array' }

$missingId = 999999999
Assert-Status (Send-TaskRequest GET "/api/tasks/$missingId") 404 'Get missing task'
Assert-Status (Send-TaskRequest PUT "/api/tasks/$missingId" @{ title = 'Missing'; isCompleted = $true }) 404 'Update missing task'
Assert-Status (Send-TaskRequest DELETE "/api/tasks/$missingId") 404 'Delete missing task'

Assert-Status (Send-TaskRequest POST '/api/tasks' @{ title = ''; description = 'Invalid' }) 400 'Create with empty title'
Assert-Status (Send-TaskRequest POST '/api/tasks' @{ title = '   ' }) 400 'Create with whitespace title'

$created = Send-TaskRequest POST '/api/tasks' @{ title = '  Learn HTTP  '; description = 'Phase 0B' }
Assert-Status $created 201 'Create task'
$task = $created.Body | ConvertFrom-Json
if ($task.id -le 0 -or $task.title -ne 'Learn HTTP' -or $task.description -ne 'Phase 0B' -or $task.isCompleted -ne $false) {
    throw 'Created task fields are incorrect'
}
if (-not $task.createdAt -or -not $task.updatedAt -or $created.Headers['Location'] -notlike "*/api/tasks/$($task.id)") {
    throw 'Created task must include timestamps and a Location header'
}

$taskPath = "/api/tasks/$($task.id)"
$fetched = Send-TaskRequest GET $taskPath
Assert-Status $fetched 200 'Get created task'
if (($fetched.Body | ConvertFrom-Json).title -ne 'Learn HTTP') { throw 'GET returned the wrong task' }

$list = Send-TaskRequest GET '/api/tasks'
Assert-Status $list 200 'List after create'
if (@($list.Body | ConvertFrom-Json | Where-Object { $_.id -eq $task.id }).Count -ne 1) {
    throw 'Created task was not found in the list'
}

Assert-Status (Send-TaskRequest PUT $taskPath @{ title = ' '; isCompleted = $true }) 400 'Update with whitespace title'
$unchanged = Send-TaskRequest GET $taskPath
if (($unchanged.Body | ConvertFrom-Json).title -ne 'Learn HTTP') { throw 'Invalid update changed the task' }

$updated = Send-TaskRequest PUT $taskPath @{ title = 'Understand HTTP'; description = 'Updated'; isCompleted = $true }
Assert-Status $updated 200 'Update task'
$updatedTask = $updated.Body | ConvertFrom-Json
if ($updatedTask.title -ne 'Understand HTTP' -or $updatedTask.description -ne 'Updated' -or $updatedTask.isCompleted -ne $true) {
    throw 'Updated task fields are incorrect'
}
if ($updatedTask.createdAt -ne $task.createdAt -or ([DateTimeOffset]$updatedTask.updatedAt) -lt ([DateTimeOffset]$task.updatedAt)) {
    throw 'Update timestamps are incorrect'
}

$fetched = Send-TaskRequest GET $taskPath
if (($fetched.Body | ConvertFrom-Json).title -ne 'Understand HTTP') { throw 'GET did not return the update' }

Assert-Status (Send-TaskRequest DELETE $taskPath) 204 'Delete task'
Assert-Status (Send-TaskRequest GET $taskPath) 404 'Get deleted task'

Write-Output "Phase 0B Task API smoke test passed: GET, POST, PUT, DELETE, 400 and 404 (task ID $($task.id))"
