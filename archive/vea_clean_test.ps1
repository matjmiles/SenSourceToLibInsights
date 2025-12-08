# VEA API Data Extraction Script
# Authenticates with VEA API and explores available endpoints

$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com"

Write-Host "=== VEA API Data Extraction ===" -ForegroundColor Green

# Step 1: Authenticate and get access token
Write-Host "Step 1: Authentication" -ForegroundColor Cyan

$AuthBody = @{
    "grant_type" = "client_credentials"
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
} | ConvertTo-Json

$Headers = @{
    "Content-Type" = "application/json"
}

try {
    Write-Host "Requesting access token..." -ForegroundColor Gray
    $TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers -ErrorAction Stop
    
    Write-Host "Authentication successful!" -ForegroundColor Green
    Write-Host "Token Type: $($TokenResponse.token_type)" -ForegroundColor Yellow
    Write-Host "Expires In: $($TokenResponse.expires_in) seconds" -ForegroundColor Yellow
    
    $AccessToken = $TokenResponse.access_token
}
catch {
    Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Explore API endpoints
Write-Host "`nStep 2: Exploring API Endpoints" -ForegroundColor Cyan

$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

# Test endpoints
$TestEndpoints = @("/api", "/api/v1", "/api/sensors", "/api/sites", "/api/data")

foreach ($endpoint in $TestEndpoints) {
    $FullUrl = "$ApiBaseUrl$endpoint"
    Write-Host "`nTrying: $FullUrl" -ForegroundColor Gray
    
    try {
        $Response = Invoke-RestMethod -Uri $FullUrl -Method Get -Headers $ApiHeaders -ErrorAction Stop
        Write-Host "SUCCESS!" -ForegroundColor Green
        
        if ($Response) {
            Write-Host "Response:" -ForegroundColor Yellow
            $Response | ConvertTo-Json -Depth 2
        }
    }
    catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nExploration Complete" -ForegroundColor Green