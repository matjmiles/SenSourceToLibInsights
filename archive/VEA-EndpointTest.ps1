# VEA API Test - Check exact endpoints
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com"

Write-Host "Testing VEA API Endpoints"

# Authenticate
$AuthBody = @{
    "grant_type" = "client_credentials"
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
} | ConvertTo-Json

$Headers = @{ "Content-Type" = "application/json" }
$TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers
$AccessToken = $TokenResponse.access_token
Write-Host "Authenticated - Token: $($AccessToken.Substring(0,10))..."

$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

# Test all endpoints from the API spec
$TestEndpoints = @(
    "/location",
    "/site", 
    "/space",
    "/sensor",
    "/zone"
)

Write-Host "`nTesting structure endpoints:"
foreach ($endpoint in $TestEndpoints) {
    $url = "$ApiBaseUrl$endpoint"
    Write-Host "`n$endpoint :"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $ApiHeaders
        Write-Host "  SUCCESS - Items: $($response.Count)"
        if ($response.Count -gt 0) {
            Write-Host "  Sample: $($response[0] | ConvertTo-Json -Compress)"
        }
    }
    catch {
        Write-Host "  FAILED: $($_.Exception.Message)"
    }
}

# Test data endpoints
$DataEndpoints = @(
    "/data/traffic",
    "/data/pos", 
    "/data/occupancy",
    "/data/queue"
)

Write-Host "`nTesting data endpoints (without date params):"
foreach ($endpoint in $DataEndpoints) {
    $url = "$ApiBaseUrl$endpoint"
    Write-Host "`n$endpoint :"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $ApiHeaders
        Write-Host "  SUCCESS"
        Write-Host "  Response type: $($response.GetType().Name)"
    }
    catch {
        Write-Host "  FAILED: $($_.Exception.Message)"
    }
}

Write-Host "`nTest complete"