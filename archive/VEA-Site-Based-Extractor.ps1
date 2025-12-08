param(
    [Parameter(Mandatory=$false)]
    [string]$StartDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd"),
    
    [Parameter(Mandatory=$false)]
    [string]$EndDate = (Get-Date).ToString("yyyy-MM-dd"),
    
    [Parameter(Mandatory=$false)]
    [string]$DataType = "traffic",
    
    [Parameter(Mandatory=$false)]
    [string]$DateGrouping = "hour",
    
    [Parameter(Mandatory=$false)]
    [string]$GateMethod = "Bidirectional"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Sensor to Site mapping from the provided data
$SensorSiteMapping = @(
    @{ SensorId = "34e07466-3cd7-4e74-889a-b63891d056b5"; SensorName = "McKay Library Level 3 Stairs"; SiteId = "729ae8ba-8fa9-4f19-9fb7-cf0a8cb8caad" },
    @{ SensorId = "5aeebd64-77eb-48c6-886b-9398703311d1"; SensorName = "McKay Library Level 2 Stairs"; SiteId = "e7d449d8-844d-4d8b-930d-c9880b681e42" },
    @{ SensorId = "508b24fa-eebf-4fa7-9ccd-0130334a99fb"; SensorName = "McKay Library Level 3 Bridge"; SiteId = "20f06728-83bd-4a83-872c-f7e9a2464614" },
    @{ SensorId = "24a57257-03c4-4220-acf7-267bc8c9c344"; SensorName = "McKay Library Level 1 Main Entrance 1"; SiteId = "d8176d0a-e6fc-4dff-8647-9913e8ced0ec" },
    @{ SensorId = "e2d3ed7a-0838-4fbf-a0e1-9b60ceaa49b4"; SensorName = "McKay Library Level 1 New Entrance"; SiteId = "ab76ad24-f717-4a4e-917a-eb772049b54b" }
)

Write-Host "VEA Site-Based Data Extractor" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan
Write-Host "Sensors/Sites to process: $($SensorSiteMapping.Count)" -ForegroundColor Cyan

# Function to authenticate
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

# Function to get site data
function Get-SiteData {
    param(
        [string]$AccessToken,
        [string]$SiteId,
        [string]$StartDate,
        [string]$EndDate,
        [string]$DataType,
        [string]$DateGrouping
    )

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    $QueryParams = @{
        "relativeDate" = "custom"
        "startDate" = $StartDate
        "endDate" = $EndDate
        "dateGroupings" = $DateGrouping
        "siteId" = $SiteId
    }

    $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
    $DataUrl = "$ApiBaseUrl/data/$DataType" + "?" + $QueryString

    try {
        $Response = Invoke-RestMethod -Uri $DataUrl -Method Get -Headers $Headers
        return $Response
    }
    catch {
        Write-Host "Failed to get data for site $SiteId : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to create Springshare CSV for a sensor/site
function Create-SpringshareCsv {
    param(
        [object]$SiteData,
        [string]$SensorName,
        [string]$GateMethod
    )

    # Clean sensor name for filename
    $SafeName = $SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
    $OutputFile = "${SafeName}_springshare_import.csv"

    if (-not $SiteData -or -not $SiteData.data.results -or $SiteData.data.results.Count -eq 0) {
        Write-Host "No data available for sensor: $SensorName" -ForegroundColor Yellow
        return
    }

    # Group by date and aggregate
    $DailyTotals = @{}
    
    foreach ($record in $SiteData.data.results) {
        if ($record.recordDate_hour_1) {
            $DateTime = [DateTime]$record.recordDate_hour_1
            $DateKey = $DateTime.ToString("yyyy-MM-dd")
            
            if (-not $DailyTotals.ContainsKey($DateKey)) {
                $DailyTotals[$DateKey] = @{
                    "TotalEntries" = 0
                    "TotalExits" = 0
                }
            }
            
            $DailyTotals[$DateKey].TotalEntries += $record.sumins
            $DailyTotals[$DateKey].TotalExits += $record.sumouts
        }
    }

    if ($DailyTotals.Count -eq 0) {
        Write-Host "No valid records for sensor: $SensorName" -ForegroundColor Yellow
        return
    }

    # Create Springshare format data
    $SpringshareRecords = @()

    foreach ($date in $DailyTotals.Keys | Sort-Object) {
        $totals = $DailyTotals[$date]
        
        switch ($GateMethod.ToLower()) {
            "bidirectional" {
                $SpringshareRecords += [PSCustomObject]@{
                    date = $date
                    gate_start = $totals.TotalEntries
                    gate_end = $totals.TotalExits
                }
            }
            "manual" {
                $SpringshareRecords += [PSCustomObject]@{
                    date = $date
                    gate_start = ($totals.TotalEntries + $totals.TotalExits)
                    gate_end = ""
                }
            }
            default {
                $SpringshareRecords += [PSCustomObject]@{
                    date = $date
                    gate_start = $totals.TotalEntries
                    gate_end = $totals.TotalExits
                }
            }
        }
    }

    # Create CSV content
    $CsvLines = @("date,gate_start,gate_end")

    foreach ($record in $SpringshareRecords) {
        if ($GateMethod.ToLower() -eq "manual") {
            $CsvLines += "$($record.date),$($record.gate_start),"
        } else {
            $CsvLines += "$($record.date),$($record.gate_start),$($record.gate_end)"
        }
    }

    # Save as UTF-8 without BOM
    $CsvContent = $CsvLines -join "`n"
    [System.IO.File]::WriteAllText($OutputFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Created: $OutputFile" -ForegroundColor Green

    # Show summary
    if ($GateMethod.ToLower() -ne "manual") {
        $TotalStart = ($SpringshareRecords | Measure-Object -Property gate_start -Sum).Sum
        $TotalEnd = ($SpringshareRecords | Measure-Object -Property gate_end -Sum).Sum  
        Write-Host "  Records: $($SpringshareRecords.Count), Entries: $TotalStart, Exits: $TotalEnd" -ForegroundColor Gray
    } else {
        $TotalCount = ($SpringshareRecords | Measure-Object -Property gate_start -Sum).Sum
        Write-Host "  Records: $($SpringshareRecords.Count), Total Count: $TotalCount" -ForegroundColor Gray
    }
}

# Main execution
Write-Host ""
Write-Host "Step 1: Authenticating..." -ForegroundColor Yellow
$AccessToken = Get-VEAAccessToken

if (-not $AccessToken) {
    Write-Host "Authentication failed. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Authenticated successfully" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Processing each site..." -ForegroundColor Yellow

$ProcessedCount = 0
$TotalSites = $SensorSiteMapping.Count

foreach ($mapping in $SensorSiteMapping) {
    $ProcessedCount++
    Write-Host ""
    Write-Host "[$ProcessedCount/$TotalSites] Processing: $($mapping.SensorName)" -ForegroundColor Cyan
    Write-Host "  Site ID: $($mapping.SiteId)" -ForegroundColor Gray
    Write-Host "  Sensor ID: $($mapping.SensorId)" -ForegroundColor Gray

    # Get data for this specific site
    $SiteData = Get-SiteData -AccessToken $AccessToken -SiteId $mapping.SiteId -StartDate $StartDate -EndDate $EndDate -DataType $DataType -DateGrouping $DateGrouping

    if ($SiteData) {
        # Create Springshare CSV for this sensor
        Create-SpringshareCsv -SiteData $SiteData -SensorName $mapping.SensorName -GateMethod $GateMethod
    } else {
        Write-Host "  No data retrieved for this site" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Processing Complete" -ForegroundColor Green
Write-Host "Processed $ProcessedCount sites/sensors" -ForegroundColor White
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor White
Write-Host "Gate Method: $GateMethod" -ForegroundColor White

# List created files
Write-Host ""
Write-Host "Created CSV files:" -ForegroundColor Cyan
Get-ChildItem -Filter "*_springshare_import.csv" | Where-Object { $_.Name -notlike "vea_traffic_*" } | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor White
}

Write-Host ""
Write-Host "Ready for Springshare LibInsights import!" -ForegroundColor Green