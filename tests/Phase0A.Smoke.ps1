param(
    [string]$BaseUrl = 'http://localhost:5162'
)

$ErrorActionPreference = 'Stop'

try {
    $health = Invoke-WebRequest "$BaseUrl/health" -UseBasicParsing
} catch {
    throw "GET /health should return 200 Healthy; $($_.Exception.Message)"
}
if ($health.StatusCode -ne 200 -or $health.Content.Trim() -ne 'Healthy') {
    throw "GET /health should return 200 Healthy; got $($health.StatusCode) $($health.Content)"
}

$openApiResponse = Invoke-WebRequest "$BaseUrl/openapi/v1.json" -UseBasicParsing
if ($openApiResponse.StatusCode -ne 200) {
    throw "GET /openapi/v1.json should return 200; got $($openApiResponse.StatusCode)"
}

$openApi = $openApiResponse.Content | ConvertFrom-Json
if ($openApi.openapi -notlike '3.*') {
    throw "Expected an OpenAPI 3 document; got $($openApi.openapi)"
}

Write-Output 'Phase 0A API smoke test passed: /health and /openapi/v1.json'
