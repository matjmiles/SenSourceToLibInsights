# VEA API Data Extraction Script
# Authenticates with VEA API and explores available endpoints

$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com"

Write-Host "=== VEA API Data Extraction ===" -ForegroundColor Green

# Step 1: Authenticate and get access token
Write-Host "`n--- Step 1: Authentication ---" -ForegroundColor Cyan

$AuthBody = @{
    "grant_type" = "client_credentials"
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
} | ConvertTo-Json

$Headers = @{
    "Content-Type" = "application/json"
}

try {
    Write-Host "Requesting access token from: $AuthUrl" -ForegroundColor Gray
    $TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers -ErrorAction Stop
    
    Write-Host "✓ Authentication successful!" -ForegroundColor Green
    Write-Host "Access Token: $($TokenResponse.access_token.Substring(0,20))..." -ForegroundColor Yellow
    Write-Host "Token Type: $($TokenResponse.token_type)" -ForegroundColor Yellow
    Write-Host "Expires In: $($TokenResponse.expires_in) seconds" -ForegroundColor Yellow
    
    $AccessToken = $TokenResponse.access_token
}
catch {
    Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Explore API endpoints
Write-Host "`n--- Step 2: Exploring API Endpoints ---" -ForegroundColor Cyan

$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

# Common endpoints to try
$Endpoints = @(
    @{ Url = "/api"; Description = "API root" },
    @{ Url = "/api/v1"; Description = "API v1" },
    @{ Url = "/api/sensors"; Description = "Sensors list" },
    @{ Url = "/api/sites"; Description = "Sites list" },
    @{ Url = "/api/data"; Description = "Data endpoint" },
    @{ Url = "/api/measurements"; Description = "Measurements" },
    @{ Url = "/api/readings"; Description = "Readings" }
)

$WorkingEndpoints = @()

foreach ($endpoint in $Endpoints) {
    $FullUrl = "$ApiBaseUrl$($endpoint.Url)"
    Write-Host "`nTrying: $($endpoint.Description) - $FullUrl" -ForegroundColor Gray
    
    try {
        $Response = Invoke-RestMethod -Uri $FullUrl -Method Get -Headers $ApiHeaders -ErrorAction Stop
        Write-Host "✓ SUCCESS!" -ForegroundColor Green
        
        $WorkingEndpoints += $endpoint
        
        # Display response preview
        if ($Response) {
            Write-Host "Response preview:" -ForegroundColor Yellow
            if ($Response -is [array] -and $Response.Count -gt 0) {
                Write-Host "Array with $($Response.Count) items. First item:" -ForegroundColor Magenta
                $Response[0] | ConvertTo-Json -Depth 2
            } else {
                $Response | ConvertTo-Json -Depth 2
            }
        }
    }
    catch {
        $StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        Write-Host "✗ Failed: HTTP $StatusCode - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 3: Show summary of working endpoints
if ($WorkingEndpoints.Count -gt 0) {
    Write-Host "`n--- Step 3: Working Endpoints Summary ---" -ForegroundColor Cyan
    Write-Host "Found $($WorkingEndpoints.Count) working endpoints:" -ForegroundColor Green
    
    foreach ($endpoint in $WorkingEndpoints) {
        Write-Host "  ✓ $($endpoint.Description): $ApiBaseUrl$($endpoint.Url)" -ForegroundColor Yellow
    }
    
    Write-Host "`nNext steps:" -ForegroundColor Green
    Write-Host "1. Use the working endpoints to explore data structure" -ForegroundColor White
    Write-Host "2. Look for date filtering parameters in the API responses" -ForegroundColor White
    Write-Host "3. Test date range queries once we understand the data format" -ForegroundColor White
} else {
    Write-Host "`n✗ No working endpoints found. The API might use different paths." -ForegroundColor Red
}

Write-Host "`n=== Exploration Complete ===" -ForegroundColor Green