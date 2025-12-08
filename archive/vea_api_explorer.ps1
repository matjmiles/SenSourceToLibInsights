# VEA API Explorer Script
# This script explores the VEA API endpoints and tests authentication

# VEA API Credentials
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$BaseUrl = "https://vea.sensourceinc.com"

Write-Host "=== VEA API Explorer ===" -ForegroundColor Green
Write-Host "Client ID: $ClientId" -ForegroundColor Yellow

# Function to get access token
function Get-VEAAccessToken {
    param(
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$BaseUrl
    )
    
    Write-Host "`nAttempting to authenticate..." -ForegroundColor Cyan
    
    # Common OAuth2 token endpoints to try
    $TokenEndpoints = @(
        "/oauth/token",
        "/api/oauth/token",
        "/auth/token",
        "/token",
        "/api/token",
        "/oauth2/token"
    )
    
    foreach ($endpoint in $TokenEndpoints) {
        $TokenUrl = "$BaseUrl$endpoint"
        Write-Host "Trying endpoint: $TokenUrl" -ForegroundColor Gray
        
        $Body = @{
            "client_id" = $ClientId
            "client_secret" = $ClientSecret
            "grant_type" = "client_credentials"
        }
        
        try {
            $Response = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
            Write-Host "✓ Success! Found working token endpoint: $TokenUrl" -ForegroundColor Green
            return $Response
        }
        catch {
            Write-Host "✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "No working token endpoint found. Trying with JSON body..." -ForegroundColor Yellow
    
    # Try with JSON body format
    foreach ($endpoint in $TokenEndpoints) {
        $TokenUrl = "$BaseUrl$endpoint"
        Write-Host "Trying endpoint with JSON: $TokenUrl" -ForegroundColor Gray
        
        $Body = @{
            "client_id" = $ClientId
            "client_secret" = $ClientSecret
            "grant_type" = "client_credentials"
        } | ConvertTo-Json
        
        try {
            $Response = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $Body -ContentType "application/json" -ErrorAction Stop
            Write-Host "✓ Success! Found working token endpoint: $TokenUrl" -ForegroundColor Green
            return $Response
        }
        catch {
            Write-Host "✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $null
}

# Function to explore API endpoints
function Explore-VEAEndpoints {
    param(
        [string]$AccessToken,
        [string]$BaseUrl
    )
    
    Write-Host "`n=== Exploring API Endpoints ===" -ForegroundColor Green
    
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }
    
    # Common API endpoints to try
    $Endpoints = @(
        "/api",
        "/api/v1",
        "/api/v2", 
        "/api/sensors",
        "/api/data",
        "/api/measurements",
        "/sensors",
        "/data",
        "/measurements",
        "/api/sites",
        "/sites"
    )
    
    foreach ($endpoint in $Endpoints) {
        $Url = "$BaseUrl$endpoint"
        Write-Host "`nTrying: $Url" -ForegroundColor Cyan
        
        try {
            $Response = Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers -ErrorAction Stop
            Write-Host "✓ Success!" -ForegroundColor Green
            Write-Host "Response:" -ForegroundColor Yellow
            $Response | ConvertTo-Json -Depth 3 | Write-Host
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "✗ Failed: HTTP $StatusCode - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Main execution
try {
    # Get access token
    $TokenResponse = Get-VEAAccessToken -ClientId $ClientId -ClientSecret $ClientSecret -BaseUrl $BaseUrl
    
    if ($TokenResponse -and $TokenResponse.access_token) {
        Write-Host "`n✓ Authentication successful!" -ForegroundColor Green
        Write-Host "Access Token: $($TokenResponse.access_token.Substring(0,20))..." -ForegroundColor Yellow
        Write-Host "Token Type: $($TokenResponse.token_type)" -ForegroundColor Yellow
        Write-Host "Expires In: $($TokenResponse.expires_in) seconds" -ForegroundColor Yellow
        
        # Explore endpoints
        Explore-VEAEndpoints -AccessToken $TokenResponse.access_token -BaseUrl $BaseUrl
    }
    else {
        Write-Host "`n✗ Authentication failed. Unable to get access token." -ForegroundColor Red
        Write-Host "Please verify your credentials and that the API is accessible." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`nUnexpected error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Exploration Complete ===" -ForegroundColor Green