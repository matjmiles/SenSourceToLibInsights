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
        "/api/token"
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
            Write-Host "Success! Found working token endpoint: $TokenUrl" -ForegroundColor Green
            return $Response
        }
        catch {
            Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $null
}

# Main execution
$TokenResponse = Get-VEAAccessToken -ClientId $ClientId -ClientSecret $ClientSecret -BaseUrl $BaseUrl

if ($TokenResponse -and $TokenResponse.access_token) {
    Write-Host "`nAuthentication successful!" -ForegroundColor Green
    Write-Host "Access Token: $($TokenResponse.access_token.Substring(0,20))..." -ForegroundColor Yellow
    
    if ($TokenResponse.token_type) {
        Write-Host "Token Type: $($TokenResponse.token_type)" -ForegroundColor Yellow
    }
    if ($TokenResponse.expires_in) {
        Write-Host "Expires In: $($TokenResponse.expires_in) seconds" -ForegroundColor Yellow
    }
    
    # Now try to explore endpoints
    Write-Host "`n=== Exploring API Endpoints ===" -ForegroundColor Green
    
    $Headers = @{
        "Authorization" = "Bearer $($TokenResponse.access_token)"
        "Content-Type" = "application/json"
    }
    
    # Common API endpoints to try
    $Endpoints = @(
        "/api",
        "/api/v1", 
        "/api/sensors",
        "/api/data",
        "/sensors",
        "/data"
    )
    
    foreach ($endpoint in $Endpoints) {
        $Url = "$BaseUrl$endpoint"
        Write-Host "`nTrying: $Url" -ForegroundColor Cyan
        
        try {
            $Response = Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers -ErrorAction Stop
            Write-Host "Success!" -ForegroundColor Green
            Write-Host "Response:" -ForegroundColor Yellow
            $Response | ConvertTo-Json -Depth 3
        }
        catch {
            Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "`nAuthentication failed. Unable to get access token." -ForegroundColor Red
}

Write-Host "`n=== Exploration Complete ===" -ForegroundColor Green