# VEA API Data Extractor - Working Version
# Extracts sensor data from VEA API with date range support

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
$ApiBaseUrl = "https://vea.sensourceinc.com/api"  # Correct base URL!

Write-Host "=== VEA Data Extractor ===" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan
Write-Host "Data Type: $DataType" -ForegroundColor Cyan
Write-Host "Grouping: $DateGrouping" -ForegroundColor Cyan

# Step 1: Authenticate
Write-Host "`nStep 1: Authentication" -ForegroundColor Yellow
$AuthBody = @{
    "grant_type" = "client_credentials"
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
} | ConvertTo-Json

$AuthHeaders = @{ "Content-Type" = "application/json" }

try {
    $TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $AuthHeaders
    Write-Host "Authentication successful!" -ForegroundColor Green
    $AccessToken = $TokenResponse.access_token
}
catch {
    Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

# Step 2: Get Available Sites and Locations
Write-Host "`nStep 2: Getting Sites and Locations" -ForegroundColor Yellow

$Sites = @()
$Locations = @()

try {
    $Sites = Invoke-RestMethod -Uri "$ApiBaseUrl/site" -Method Get -Headers $ApiHeaders
    Write-Host "Sites found: $($Sites.Count)" -ForegroundColor Green
    foreach ($site in $Sites) {
        Write-Host "  - Site: $($site.name) (ID: $($site.id))" -ForegroundColor White
    }
}
catch {
    Write-Host "Failed to get sites: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $Locations = Invoke-RestMethod -Uri "$ApiBaseUrl/location" -Method Get -Headers $ApiHeaders  
    Write-Host "Locations found: $($Locations.Count)" -ForegroundColor Green
    foreach ($location in $Locations) {
        Write-Host "  - Location: $($location.name) (ID: $($location.id))" -ForegroundColor White
    }
}
catch {
    Write-Host "Failed to get locations: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 3: Extract Data with Date Range
Write-Host "`nStep 3: Extracting $DataType Data" -ForegroundColor Yellow

# Build query parameters for date range
$QueryParams = @{
    "relativeDate" = "custom"
    "startDate" = $StartDate  
    "endDate" = $EndDate
    "dateGroupings" = $DateGrouping
}

$QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
$DataUrl = "$ApiBaseUrl/data/$DataType" + "?" + $QueryString

Write-Host "Request URL: $DataUrl" -ForegroundColor Gray

try {
    $Data = Invoke-RestMethod -Uri $DataUrl -Method Get -Headers $ApiHeaders
    Write-Host "Data extraction successful!" -ForegroundColor Green
    
    # Analyze the data
    if ($Data -is [array]) {
        Write-Host "Records returned: $($Data.Count)" -ForegroundColor White
    } elseif ($Data) {
        Write-Host "Data object returned: $($Data.GetType().Name)" -ForegroundColor White
    }
    
    # Step 4: Save to File
    $OutputFile = "vea_${DataType}_${StartDate}_to_${EndDate}.json"
    
    $ExportData = @{
        "extraction_timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        "parameters" = @{
            "start_date" = $StartDate
            "end_date" = $EndDate
            "data_type" = $DataType
            "date_grouping" = $DateGrouping
        }
        "sites" = $Sites
        "locations" = $Locations  
        "data" = $Data
    }
    
    $ExportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Data saved to: $OutputFile" -ForegroundColor Green
    
    # Show preview of data
    if ($Data -is [array] -and $Data.Count -gt 0) {
        Write-Host "`nFirst record preview:" -ForegroundColor Yellow
        $Data[0] | ConvertTo-Json -Depth 2 | Write-Host
    } elseif ($Data) {
        Write-Host "`nData preview:" -ForegroundColor Yellow  
        $Data | ConvertTo-Json -Depth 2 | Write-Host
    }
    
}
catch {
    Write-Host "Data extraction failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host "`n=== Extraction Complete ===" -ForegroundColor Green

# Show usage examples
Write-Host "`n=== Usage Examples ===" -ForegroundColor Cyan
Write-Host "Basic usage (last 7 days traffic data):" -ForegroundColor White
Write-Host "  .\VEA-DataExtractor.ps1" -ForegroundColor Gray
Write-Host "`nCustom date range:" -ForegroundColor White  
Write-Host "  .\VEA-DataExtractor.ps1 -StartDate '2025-12-01' -EndDate '2025-12-07'" -ForegroundColor Gray
Write-Host "`nDifferent data types:" -ForegroundColor White
Write-Host "  .\VEA-DataExtractor.ps1 -DataType 'occupancy'" -ForegroundColor Gray
Write-Host "  .\VEA-DataExtractor.ps1 -DataType 'pos'" -ForegroundColor Gray
Write-Host "`nDifferent groupings:" -ForegroundColor White
Write-Host "  .\VEA-DataExtractor.ps1 -DateGrouping 'day'" -ForegroundColor Gray
Write-Host "  .\VEA-DataExtractor.ps1 -DateGrouping 'minute(15)'" -ForegroundColor Gray