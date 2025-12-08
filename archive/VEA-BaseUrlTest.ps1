# VEA API Base URL Test
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"

Write-Host "Testing VEA API Base URLs"

# Authenticate
$AuthBody = @{
    "grant_type" = "client_credentials"
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
} | ConvertTo-Json

$Headers = @{ "Content-Type" = "application/json" }
$TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers
$AccessToken = $TokenResponse.access_token

$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

# Test different base URLs and versions
$BaseUrls = @(
    "https://vea.sensourceinc.com",
    "https://api.sensourceinc.com", 
    "https://vea.sensourceinc.com/api",
    "https://vea.sensourceinc.com/v1",
    "https://vea.sensourceinc.com/api/v1",
    "https://api.vea.sensourceinc.com"
)

foreach ($baseUrl in $BaseUrls) {
    Write-Host "`nTesting base URL: $baseUrl"
    
    # Try simple endpoints
    $testPaths = @("/site", "/location", "/data/traffic")
    
    foreach ($path in $testPaths) {
        $fullUrl = "$baseUrl$path"
        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Method Get -Headers $ApiHeaders -ErrorAction Stop
            Write-Host "  SUCCESS: $path" -ForegroundColor Green
            if ($response) {
                Write-Host "    Response: $($response.GetType().Name)" -ForegroundColor Yellow
            }
        }
        catch {
            $status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { "Unknown" }
            Write-Host "  ${status}: $path" -ForegroundColor Red
        }
    }
}

Write-Host "`nTest complete"