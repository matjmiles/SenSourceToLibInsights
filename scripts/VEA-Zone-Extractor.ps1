param(
    [string]$StartDate = "2025-12-01T00:00:00Z",
    [string]$EndDate = "2025-12-08T23:59:59Z",
    [string]$DataType = "traffic",
    [string]$DateGrouping = "hour",
    [string]$GateMethod = "Bidirectional"
)

# VEA API Configuration - Load from external config file
$ConfigPath = Join-Path $PSScriptRoot "..\config.ps1"
if (Test-Path $ConfigPath) {
    . $ConfigPath
} else {
    Write-Error "Configuration file not found: $ConfigPath"
    Write-Host "Please create config.ps1 with your VEA API credentials. See config.example.ps1 for template."
    exit 1
}

$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Sensor ID to friendly name mapping
$SensorNameMap = @{
    "34e07466-3cd7-4e74-889a-b63891d056b5" = "McKay Library Level 3 Stairs"
    "5aeebd64-77eb-48c6-886b-9398703311d1" = "McKay Library Level 2 Stairs" 
    "508b24fa-eebf-4fa7-9ccd-0130334a99fb" = "McKay Library Level 3 Bridge"
    "24a57257-03c4-4220-acf7-267bc8c9c344" = "McKay Library Level 1 Main Entrance 1"
    "e2d3ed7a-0838-4fbf-a0e1-9b60ceaa49b4" = "McKay Library Level 1 New Entrance"
}

# Handle different date input formats
if ($StartDate -notmatch 'T.*Z$') {
    # Convert yyyy-mm-dd to full ISO-8601 format
    $StartDate = "${StartDate}T00:00:00Z"
}
if ($EndDate -notmatch 'T.*Z$') {
    # Convert yyyy-mm-dd to full ISO-8601 format  
    $EndDate = "${EndDate}T23:59:59Z"
}

Write-Host "VEA Zone-Based Individual Sensor Extractor" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan
Write-Host "Data Type: $DataType | Grouping: $DateGrouping" -ForegroundColor Cyan
Write-Host "Gate Method: $GateMethod" -ForegroundColor Cyan

# Authentication function
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

# Get zones from API
function Get-VEAZones {
    param([string]$AccessToken)
    
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    try {
        $Response = Invoke-RestMethod -Uri "$ApiBaseUrl/zone" -Method Get -Headers $Headers
        return $Response
    }
    catch {
        Write-Host "Failed to get zones: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Get traffic data for a specific zone
function Get-ZoneTrafficData {
    param(
        [string]$AccessToken,
        [string]$ZoneId,
        [string]$ZoneName,
        [string]$StartDate,
        [string]$EndDate,
        [string]$DateGrouping
    )
    
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    # Build URL for zone-specific traffic data
    $BaseUrl = "$ApiBaseUrl/data/traffic"
    $Params = @(
        "relativeDate=custom",
        "startDate=$StartDate",
        "endDate=$EndDate", 
        "dateGroupings=$DateGrouping",
        "entityType=zone",
        "zoneId=$ZoneId"
    )
    
    $DataUrl = $BaseUrl + "?" + ($Params -join "&")
    
    Write-Host "  Querying zone: $ZoneName" -ForegroundColor Yellow
    Write-Host "  Zone ID: $ZoneId" -ForegroundColor Gray
    Write-Host "  URL: $DataUrl" -ForegroundColor DarkGray

    try {
        $Response = Invoke-RestMethod -Uri $DataUrl -Method Get -Headers $Headers
        
        if ($Response.results -and $Response.results.Count -gt 0) {
            Write-Host "  Success: $($Response.results.Count) records" -ForegroundColor Green
            return $Response
        } else {
            Write-Host "  No data returned for this zone" -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Create Springshare CSV from zone data
function Create-ZoneSpringshareCSV {
    param(
        [object]$ZoneData,
        [string]$SensorName,
        [string]$ZoneId,
        [string]$GateMethod
    )

    $SafeName = $SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
    $CsvFile = "${SafeName}_springshare_import.csv"
    $JsonFile = "${SafeName}_zone_data.json"

    # Save raw zone data
    $ZoneDataPackage = @{
        zone_info = @{
            zone_id = $ZoneId
            sensor_name = $SensorName
            extraction_timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        raw_data = $ZoneData
    }
    
    $ZoneDataPackage | ConvertTo-Json -Depth 15 | Out-File -FilePath $JsonFile -Encoding UTF8
    Write-Host "  Saved raw data: $JsonFile" -ForegroundColor Gray

    # Group by date (convert hourly to daily)
    $DailyTotals = @{}
    
    foreach ($record in $ZoneData.results) {
        $DateField = $null
        $DateTime = $null
        
        # Handle different date field formats
        if ($record.recordDate_hour_1) {
            $DateTime = [DateTime]$record.recordDate_hour_1
        } elseif ($record.recordDate_day_1) {
            $DateTime = [DateTime]$record.recordDate_day_1
        } elseif ($record.recordDate_month_1) {
            $DateTime = [DateTime]$record.recordDate_month_1
        }
        
        if ($DateTime) {
            $DateKey = $DateTime.ToString("yyyy-MM-dd")
            
            if (-not $DailyTotals.ContainsKey($DateKey)) {
                $DailyTotals[$DateKey] = @{
                    Entries = 0
                    Exits = 0
                }
            }
            
            # Add entries and exits
            if ($record.sumins) {
                $DailyTotals[$DateKey].Entries += [int]$record.sumins
            }
            if ($record.sumouts) {
                $DailyTotals[$DateKey].Exits += [int]$record.sumouts
            }
        }
    }

    if ($DailyTotals.Count -eq 0) {
        Write-Host "  No valid daily records found" -ForegroundColor Yellow
        return $null
    }

    # Create Springshare CSV format
    $CsvLines = @("date,gate_start,gate_end")
    
    foreach ($date in $DailyTotals.Keys | Sort-Object) {
        $totals = $DailyTotals[$date]
        
        switch ($GateMethod.ToLower()) {
            "bidirectional" {
                $CsvLines += "$date,$($totals.Entries),$($totals.Exits)"
            }
            "manual" {
                $total = $totals.Entries + $totals.Exits
                $CsvLines += "$date,$total,"
            }
            default {
                $CsvLines += "$date,$($totals.Entries),$($totals.Exits)"
            }
        }
    }

    # Save CSV file
    $CsvContent = $CsvLines -join "`n"
    [System.IO.File]::WriteAllText($CsvFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "  Created CSV: $CsvFile" -ForegroundColor Green
    
    # Show summary
    $TotalEntries = ($DailyTotals.Values | Measure-Object -Property Entries -Sum).Sum
    $TotalExits = ($DailyTotals.Values | Measure-Object -Property Exits -Sum).Sum
    
    if ($GateMethod.ToLower() -ne "manual") {
        Write-Host "     $($DailyTotals.Count) days | Entries: $TotalEntries | Exits: $TotalExits" -ForegroundColor Gray
    } else {
        $TotalCount = $TotalEntries + $TotalExits
        Write-Host "     $($DailyTotals.Count) days | Total Count: $TotalCount" -ForegroundColor Gray
    }

    return $CsvFile
}

# Main execution
Write-Host ""
Write-Host "Step 1: Authentication" -ForegroundColor Yellow
$AccessToken = Get-VEAAccessToken

if (-not $AccessToken) {
    Write-Host "Cannot proceed without authentication. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Authentication successful" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Getting zones list" -ForegroundColor Yellow
$Zones = Get-VEAZones -AccessToken $AccessToken

if (-not $Zones -or $Zones.Count -eq 0) {
    Write-Host "No zones found or error getting zones. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($Zones.Count) zones" -ForegroundColor Green

# Save zones data for reference
$Zones | ConvertTo-Json -Depth 10 | Out-File -FilePath "vea_zones_list.json" -Encoding UTF8
Write-Host "Saved zones list to: vea_zones_list.json" -ForegroundColor Gray

Write-Host ""
Write-Host "Step 3: Processing each zone" -ForegroundColor Yellow

$ProcessedZones = @()
$CreatedFiles = @()
$SuccessCount = 0

foreach ($zone in $Zones) {
    Write-Host ""
    Write-Host "Processing Zone:" -ForegroundColor Cyan
    Write-Host "   Zone ID: $($zone.zoneId)" -ForegroundColor Gray
    Write-Host "   Zone Name: $($zone.name)" -ForegroundColor Gray
    Write-Host "   Sensor ID: $($zone.sensorId)" -ForegroundColor Gray
    
    # Get friendly sensor name
    $SensorName = $SensorNameMap[$zone.sensorId]
    if (-not $SensorName) {
        $SensorName = "Unknown Sensor $($zone.sensorId)"
        Write-Host "   Unknown sensor, using generic name" -ForegroundColor Yellow
    }
    
    Write-Host "   Friendly Name: $SensorName" -ForegroundColor Cyan
    
    # Get zone traffic data
    $ZoneData = Get-ZoneTrafficData -AccessToken $AccessToken -ZoneId $zone.zoneId -ZoneName $zone.name -StartDate $StartDate -EndDate $EndDate -DateGrouping $DateGrouping
    
    if ($ZoneData) {
        $CsvFile = Create-ZoneSpringshareCSV -ZoneData $ZoneData -SensorName $SensorName -ZoneId $zone.zoneId -GateMethod $GateMethod
        
        if ($CsvFile) {
            $CreatedFiles += $CsvFile
            $SuccessCount++
        }
        
        $ProcessedZones += @{
            ZoneId = $zone.zoneId
            ZoneName = $zone.name
            SensorId = $zone.sensorId
            SensorName = $SensorName
            Success = $true
            CsvFile = $CsvFile
        }
    } else {
        $ProcessedZones += @{
            ZoneId = $zone.zoneId
            ZoneName = $zone.name
            SensorId = $zone.sensorId
            SensorName = $SensorName
            Success = $false
        }
        Write-Host "   Failed to get data for this zone" -ForegroundColor Red
    }
}

# Final Summary
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "ZONE-BASED EXTRACTION COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor White
Write-Host "Gate Method: $GateMethod" -ForegroundColor White
Write-Host "Successful extractions: $SuccessCount / $($Zones.Count)" -ForegroundColor White

if ($CreatedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Created Springshare Import Files:" -ForegroundColor Cyan
    foreach ($file in $CreatedFiles) {
        Write-Host "   $file" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Ready for Springshare LibInsights import!" -ForegroundColor Green
    Write-Host "Each CSV file contains REAL individual sensor data from VEA zones!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "WARNING: No sensor data was successfully extracted!" -ForegroundColor Yellow
}

Write-Host ""