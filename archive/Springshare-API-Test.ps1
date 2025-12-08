# Springshare LibApps API Explorer
# Test to discover available endpoints and data formats

# NOTE: You'll need to get actual Springshare API credentials
# This is a template to test with when you have them

param(
    [string]$ClientId = "YOUR_SPRINGSHARE_CLIENT_ID",
    [string]$ClientSecret = "YOUR_SPRINGSHARE_CLIENT_SECRET"
)

$AuthUrl = "https://lgapi-us.libapps.com/1.2/oauth/token"
$ApiBaseUrl = "https://lgapi-us.libapps.com/1.2"

Write-Host "=== Springshare LibApps API Explorer ===" -ForegroundColor Green
Write-Host "NOTE: This requires valid Springshare API credentials" -ForegroundColor Yellow

if ($ClientId -eq "YOUR_SPRINGSHARE_CLIENT_ID") {
    Write-Host "❌ Please provide actual Springshare API credentials" -ForegroundColor Red
    Write-Host "Usage: .\Springshare-API-Test.ps1 -ClientId 'your_id' -ClientSecret 'your_secret'" -ForegroundColor Gray
    exit 1
}

# Step 1: Test Authentication
Write-Host "`nStep 1: Testing Authentication" -ForegroundColor Cyan

$AuthBody = @{
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
    "grant_type" = "client_credentials"
}

try {
    $TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -ContentType "application/x-www-form-urlencoded"
    Write-Host "✓ Authentication successful!" -ForegroundColor Green
    $AccessToken = $TokenResponse.access_token
}
catch {
    Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
    exit 1
}

$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

# Step 2: Explore API Endpoints
Write-Host "`nStep 2: Exploring API Endpoints" -ForegroundColor Cyan

# Test common endpoints that might relate to LibInsights
$TestEndpoints = @(
    @{ Path = ""; Description = "API Root" },
    @{ Path = "/sites"; Description = "Sites" },
    @{ Path = "/guides"; Description = "LibGuides" },
    @{ Path = "/analytics"; Description = "Analytics" },
    @{ Path = "/insights"; Description = "LibInsights" }, 
    @{ Path = "/statistics"; Description = "Statistics" },
    @{ Path = "/data"; Description = "Data" },
    @{ Path = "/reports"; Description = "Reports" },
    @{ Path = "/import"; Description = "Import" },
    @{ Path = "/upload"; Description = "Upload" }
)

$WorkingEndpoints = @()

foreach ($endpoint in $TestEndpoints) {
    $FullUrl = "$ApiBaseUrl$($endpoint.Path)"
    Write-Host "`nTesting: $($endpoint.Description) - $FullUrl" -ForegroundColor Gray
    
    try {
        $Response = Invoke-RestMethod -Uri $FullUrl -Method Get -Headers $ApiHeaders -ErrorAction Stop
        Write-Host "  ✓ SUCCESS!" -ForegroundColor Green
        $WorkingEndpoints += $endpoint
        
        # Show response structure
        if ($Response) {
            Write-Host "  Response type: $($Response.GetType().Name)" -ForegroundColor Yellow
            if ($Response -is [array] -and $Response.Count -gt 0) {
                Write-Host "  Array with $($Response.Count) items" -ForegroundColor White
            } elseif ($Response -is [PSCustomObject]) {
                Write-Host "  Object with properties: $($Response.PSObject.Properties.Name -join ', ')" -ForegroundColor White
            }
        }
    }
    catch {
        $StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        Write-Host "  ✗ Failed: HTTP $StatusCode" -ForegroundColor Red
    }
}

# Step 3: Test POST endpoints for data submission
Write-Host "`nStep 3: Testing POST Endpoints for Data Import" -ForegroundColor Cyan

$PostEndpoints = @(
    "/analytics",
    "/insights", 
    "/statistics",
    "/data",
    "/import"
)

$SampleData = @{
    "date" = (Get-Date).ToString("yyyy-MM-dd")
    "metric" = "visits"
    "value" = 100
} | ConvertTo-Json

foreach ($endpoint in $PostEndpoints) {
    $FullUrl = "$ApiBaseUrl$endpoint"
    Write-Host "`nTesting POST: $FullUrl" -ForegroundColor Gray
    
    try {
        $Response = Invoke-RestMethod -Uri $FullUrl -Method Post -Body $SampleData -Headers $ApiHeaders -ErrorAction Stop
        Write-Host "  ✓ POST SUCCESS!" -ForegroundColor Green
        Write-Host "  Response: $($Response | ConvertTo-Json -Depth 2)" -ForegroundColor Yellow
    }
    catch {
        $StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        Write-Host "  ✗ POST Failed: HTTP $StatusCode" -ForegroundColor Red
    }
}

# Step 4: Summary
Write-Host "`n=== Summary ===" -ForegroundColor Green

if ($WorkingEndpoints.Count -gt 0) {
    Write-Host "Working GET endpoints:" -ForegroundColor Cyan
    foreach ($endpoint in $WorkingEndpoints) {
        Write-Host "  ✓ $($endpoint.Description): $ApiBaseUrl$($endpoint.Path)" -ForegroundColor White
    }
} else {
    Write-Host "No working endpoints found" -ForegroundColor Red
}

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Contact Springshare support about LibInsights data import" -ForegroundColor White
Write-Host "2. Check LibInsights UI for manual import options" -ForegroundColor White
Write-Host "3. Ask about supported data formats (CSV, JSON, etc.)" -ForegroundColor White