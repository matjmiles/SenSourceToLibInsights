# VEA API Data Extractor - Simple Version
param(
    [string]$StartDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd"),
    [string]$EndDate = (Get-Date).ToString("yyyy-MM-dd"),
    [string]$DataType = "traffic",
    [string]$DateGrouping = "hour"
)

# Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com"

Write-Host "=== VEA Data Extractor ===" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Yellow
Write-Host "Data Type: $DataType" -ForegroundColor Yellow

# Step 1: Authenticate
Write-Host "`nStep 1: Authentication" -ForegroundColor Cyan
$AuthBody = @{
    "grant_type" = "client_credentials"
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
} | ConvertTo-Json

$Headers = @{ "Content-Type" = "application/json" }

try {
    $TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers
    Write-Host "✓ Authentication successful" -ForegroundColor Green
    $AccessToken = $TokenResponse.access_token
}
catch {
    Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Get Sites
Write-Host "`nStep 2: Getting Sites" -ForegroundColor Cyan
$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

try {
    $Sites = Invoke-RestMethod -Uri "$ApiBaseUrl/site" -Method Get -Headers $ApiHeaders
    Write-Host "✓ Found $($Sites.Count) sites" -ForegroundColor Green
    foreach ($site in $Sites) {
        Write-Host "  - $($site.name) (ID: $($site.id))" -ForegroundColor White
    }
}
catch {
    Write-Host "✗ Failed to get sites: $($_.Exception.Message)" -ForegroundColor Red
    $Sites = @()
}

# Step 3: Get Data
Write-Host "`nStep 3: Extracting Data" -ForegroundColor Cyan
$QueryString = "relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=$DateGrouping"
$DataUrl = "$ApiBaseUrl/data/$DataType" + "?" + $QueryString

Write-Host "Request: $DataUrl" -ForegroundColor Gray

try {
    $Data = Invoke-RestMethod -Uri $DataUrl -Method Get -Headers $ApiHeaders
    Write-Host "✓ Data extraction successful" -ForegroundColor Green
    
    if ($Data -is [array]) {
        Write-Host "Records: $($Data.Count)" -ForegroundColor White
    }
    
    # Save to file
    $OutputData = @{
        "extraction_timestamp" = Get-Date
        "parameters" = @{
            "start_date" = $StartDate
            "end_date" = $EndDate
            "data_type" = $DataType
            "date_grouping" = $DateGrouping
        }
        "sites" = $Sites
        "data" = $Data
    }
    
    $OutputFile = "vea_$DataType" + "_$StartDate" + "_to_$EndDate.json"
    $OutputData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "✓ Data saved to: $OutputFile" -ForegroundColor Green
    
    # Show preview
    if ($Data -is [array] -and $Data.Count -gt 0) {
        Write-Host "`nSample data:" -ForegroundColor Yellow
        $Data[0] | ConvertTo-Json -Depth 2
    }
}
catch {
    Write-Host "✗ Data extraction failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Complete ===" -ForegroundColor Green