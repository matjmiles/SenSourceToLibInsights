# VEA API Authentication Test
# Testing different authentication methods

$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$BaseUrl = "https://vea.sensourceinc.com"

Write-Host "=== Testing VEA API Authentication Methods ===" -ForegroundColor Green

# Test endpoints that returned 401 (they exist!)
$WorkingEndpoints = @("/api/oauth/token", "/api/token")

foreach ($endpoint in $WorkingEndpoints) {
    $TokenUrl = "$BaseUrl$endpoint"
    Write-Host "`n--- Testing endpoint: $TokenUrl ---" -ForegroundColor Cyan
    
    # Method 1: Form-encoded body
    Write-Host "Method 1: Form-encoded body" -ForegroundColor Yellow
    $Body1 = @{
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
        "grant_type" = "client_credentials"
    }
    
    try {
        $Response = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $Body1 -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
        Write-Host "SUCCESS with form-encoded!" -ForegroundColor Green
        $Response | ConvertTo-Json
        break
    }
    catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 2: JSON body
    Write-Host "Method 2: JSON body" -ForegroundColor Yellow
    $Body2 = @{
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
        "grant_type" = "client_credentials"
    } | ConvertTo-Json
    
    try {
        $Response = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $Body2 -ContentType "application/json" -ErrorAction Stop
        Write-Host "SUCCESS with JSON!" -ForegroundColor Green
        $Response | ConvertTo-Json
        break
    }
    catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 3: Basic Auth header
    Write-Host "Method 3: Basic Auth in header" -ForegroundColor Yellow
    $EncodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${ClientId}:${ClientSecret}"))
    $Headers3 = @{
        "Authorization" = "Basic $EncodedCreds"
        "Content-Type" = "application/x-www-form-urlencoded"
    }
    $Body3 = "grant_type=client_credentials"
    
    try {
        $Response = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $Body3 -Headers $Headers3 -ErrorAction Stop
        Write-Host "SUCCESS with Basic Auth!" -ForegroundColor Green
        $Response | ConvertTo-Json
        break
    }
    catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 4: Try without grant_type
    Write-Host "Method 4: Without grant_type" -ForegroundColor Yellow
    $Body4 = @{
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
    }
    
    try {
        $Response = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $Body4 -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
        Write-Host "SUCCESS without grant_type!" -ForegroundColor Green
        $Response | ConvertTo-Json
        break
    }
    catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Also try to access the API documentation directly
Write-Host "`n--- Trying to access API documentation ---" -ForegroundColor Cyan
$DocEndpoints = @("/api", "/api/docs", "/api-docs", "/docs", "/swagger", "/api/swagger")

foreach ($docEndpoint in $DocEndpoints) {
    $DocUrl = "$BaseUrl$docEndpoint"
    Write-Host "Trying: $DocUrl" -ForegroundColor Gray
    
    try {
        $Response = Invoke-WebRequest -Uri $DocUrl -Method Get -ErrorAction Stop
        Write-Host "SUCCESS! Found documentation at: $DocUrl" -ForegroundColor Green
        Write-Host "Status: $($Response.StatusCode)" -ForegroundColor Yellow
        Write-Host "Content preview:" -ForegroundColor Yellow
        Write-Host $Response.Content.Substring(0, [Math]::Min(500, $Response.Content.Length))
        break
    }
    catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Authentication Test Complete ===" -ForegroundColor Green