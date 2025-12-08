param(
    [string]$StartDate = "2025-12-01",
    [string]$EndDate = "2025-12-08"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Sensor to Site mapping from your sensor list
$SensorSiteMap = @(
    @{ SensorId = "34e07466-3cd7-4e74-889a-b63891d056b5"; Name = "McKay Library Level 3 Stairs"; SiteId = "729ae8ba-8fa9-4f19-9fb7-cf0a8cb8caad" },
    @{ SensorId = "5aeebd64-77eb-48c6-886b-9398703311d1"; Name = "McKay Library Level 2 Stairs"; SiteId = "e7d449d8-844d-4d8b-930d-c9880b681e42" },
    @{ SensorId = "508b24fa-eebf-4fa7-9ccd-0130334a99fb"; Name = "McKay Library Level 3 Bridge"; SiteId = "20f06728-83bd-4a83-872c-f7e9a2464614" },
    @{ SensorId = "24a57257-03c4-4220-acf7-267bc8c9c344"; Name = "McKay Library Level 1 Main Entrance 1"; SiteId = "d8176d0a-e6fc-4dff-8647-9913e8ced0ec" },
    @{ SensorId = "e2d3ed7a-0838-4fbf-a0e1-9b60ceaa49b4"; Name = "McKay Library Level 1 New Entrance"; SiteId = "ab76ad24-f717-4a4e-917a-eb772049b54b" }
)

Write-Host "VEA Site-Based Sensor Data Extraction" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan

# Authentication
function Get-VEAAccessToken {
    $AuthBody = @{
        "grant_type" = "client_credentials"
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
    } | ConvertTo-Json

    $Headers = @{ "Content-Type" = "application/json" }

    try {
        $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers
        return $Response.access_token
    }
    catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Try querying by site ID
function Get-SiteData {
    param(
        [string]$AccessToken,
        [string]$SiteId,
        [string]$SensorName
    )

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    $TestUrls = @(
        "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&siteId=$SiteId",
        "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&site=$SiteId",
        "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&sites=$SiteId"
    )

    Write-Host "  Testing: $SensorName" -ForegroundColor Yellow
    Write-Host "  Site ID: $SiteId" -ForegroundColor Gray

    foreach ($url in $TestUrls) {
        Write-Host "    Trying: $url" -ForegroundColor DarkGray

        try {
            $Response = Invoke-RestMethod -Uri $url -Method Get -Headers $Headers
            
            if ($Response.data.results -and $Response.data.results.Count -gt 0) {
                Write-Host "    SUCCESS: $($Response.data.results.Count) records" -ForegroundColor Green
                return $Response
            } else {
                Write-Host "    No data" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    return $null
}

# Create individual CSV files
function Create-SensorCSV {
    param(
        [object]$SiteData,
        [string]$SensorName
    )

    $SafeName = $SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
    $CsvFile = "${SafeName}_springshare_import.csv"
    $JsonFile = "${SafeName}_data.json"

    # Save the raw JSON data
    $SiteData | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFile -Encoding UTF8
    Write-Host "  Saved: $JsonFile" -ForegroundColor Gray

    # Group by date
    $DailyTotals = @{}
    
    foreach ($record in $SiteData.data.results) {
        if ($record.recordDate_hour_1) {
            $DateTime = [DateTime]$record.recordDate_hour_1
            $DateKey = $DateTime.ToString("yyyy-MM-dd")
            
            if (-not $DailyTotals.ContainsKey($DateKey)) {
                $DailyTotals[$DateKey] = @{
                    Entries = 0
                    Exits = 0
                }
            }
            
            $DailyTotals[$DateKey].Entries += [int]$record.sumins
            $DailyTotals[$DateKey].Exits += [int]$record.sumouts
        }
    }

    if ($DailyTotals.Count -eq 0) {
        Write-Host "  No valid data for CSV creation" -ForegroundColor Yellow
        return $null
    }

    # Create Springshare CSV
    $CsvLines = @("date,gate_start,gate_end")

    foreach ($date in $DailyTotals.Keys | Sort-Object) {
        $totals = $DailyTotals[$date]
        $CsvLines += "$date,$($totals.Entries),$($totals.Exits)"
    }

    # Save file
    $CsvContent = $CsvLines -join "`n"
    [System.IO.File]::WriteAllText($CsvFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "  Created: $CsvFile" -ForegroundColor Green
    
    # Show summary
    $TotalEntries = ($DailyTotals.Values | Measure-Object -Property Entries -Sum).Sum
    $TotalExits = ($DailyTotals.Values | Measure-Object -Property Exits -Sum).Sum
    Write-Host "    Days: $($DailyTotals.Count) | Entries: $TotalEntries | Exits: $TotalExits" -ForegroundColor Gray
    
    return $CsvFile
}

# Main execution
Write-Host ""
Write-Host "Authenticating..." -ForegroundColor Yellow
$AccessToken = Get-VEAAccessToken

if (-not $AccessToken) {
    Write-Host "Authentication failed. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Authentication successful" -ForegroundColor Green
Write-Host ""

$CreatedFiles = @()
$SuccessCount = 0

foreach ($mapping in $SensorSiteMap) {
    Write-Host "Processing: $($mapping.Name)" -ForegroundColor Cyan
    
    $SiteData = Get-SiteData -AccessToken $AccessToken -SiteId $mapping.SiteId -SensorName $mapping.Name
    
    if ($SiteData) {
        $CsvFile = Create-SensorCSV -SiteData $SiteData -SensorName $mapping.Name
        if ($CsvFile) {
            $CreatedFiles += $CsvFile
            $SuccessCount++
        }
    }
    
    Write-Host ""
}

Write-Host "Processing Complete" -ForegroundColor Green
Write-Host "Successfully processed: $SuccessCount / $($SensorSiteMap.Count) sensors" -ForegroundColor White

if ($CreatedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Created CSV files:" -ForegroundColor Cyan
    foreach ($file in $CreatedFiles) {
        Write-Host "  $file" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Ready for Springshare LibInsights import!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "No individual sensor data could be extracted." -ForegroundColor Yellow
    Write-Host "The VEA API might aggregate all sensor data at the location level." -ForegroundColor Yellow
}