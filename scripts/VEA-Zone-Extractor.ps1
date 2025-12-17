param(
    [string]$StartDate,  # Will be auto-calculated if not provided
    [string]$EndDate,    # Will be auto-calculated if not provided
    [string]$DataType = "traffic",
    [string]$DateGrouping = "hour",
    [string]$GateMethod = "Bidirectional"
)

# Load required modules
$modules = @(
    "VeaCredentialManager.ps1",
    "VeaValidator.ps1",
    "VeaExceptions.ps1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $PSScriptRoot $module
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

# Set error handling preference
$ErrorActionPreference = "Stop"

# Calculate automatic date range for current year
function Get-AutomaticDateRange {
    $currentDate = [DateTime]::Now

    # Start date: First day of current year at midnight UTC
    $startOfYear = [DateTime]::new($currentDate.Year, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    $startDate = $startOfYear.ToString("yyyy-MM-ddTHH:mm:ssZ")

    # End date: Current date at 23:59:59 UTC (end of today)
    $endOfDay = [DateTime]::new($currentDate.Year, $currentDate.Month, $currentDate.Day, 23, 59, 59, [DateTimeKind]::Utc)
    $endDate = $endOfDay.ToString("yyyy-MM-ddTHH:mm:ssZ")

    return @{
        StartDate = $startDate
        EndDate = $endDate
    }
}

# Calculate automatic dates if not provided
if (-not $StartDate -or -not $EndDate) {
    Write-Host "Calculating automatic date range for current year..." -ForegroundColor Cyan
    $dateRange = Get-AutomaticDateRange
    if (-not $StartDate) {
        $StartDate = $dateRange.StartDate
        Write-Host "Auto Start Date: $StartDate" -ForegroundColor Gray
    }
    if (-not $EndDate) {
        $EndDate = $dateRange.EndDate
        Write-Host "Auto End Date: $EndDate" -ForegroundColor Gray
    }
}

# Validate script parameters
$paramValidation = [VeaValidator]::TestScriptParameters(@{
    StartDate = $StartDate
    EndDate = $EndDate
    DataType = $DataType
    DateGrouping = $DateGrouping
    GateMethod = $GateMethod
})

if (-not $paramValidation) {
    exit 1
}

# Load secure credentials
try {
    $credentials = Invoke-VeaSafe { Get-VeaCredentials } "credential retrieval"
    $ClientId = $credentials.ClientId
    $ClientSecret = $credentials.ClientSecret
} catch {
    Write-Error "Failed to load credentials. Please run setup.bat to configure your VEA API credentials."
    exit 1
}

# Validate API credentials
Write-Host "Validating API credentials..." -ForegroundColor Cyan
$credentialTest = Invoke-VeaRetry { Test-VeaApiCredentials -ClientId $ClientId -ClientSecret $ClientSecret }

if (-not $credentialTest) {
    Write-Error "API credential validation failed. Please check your credentials and network connectivity."
    exit 1
}

Write-Host "API credentials validated successfully" -ForegroundColor Green

# Get zones from API with proper error handling
function Get-VEAZones {
    param([string]$AccessToken)

    try {
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type" = "application/json"
        }

        $response = Invoke-VeaRetry {
            Invoke-RestMethod -Uri "$ApiBaseUrl/zone" -Method Get -Headers $headers -TimeoutSec 30
        }

        if (-not $response -or $response.Count -eq 0) {
            throw [VeaDataException]::new("No zones returned from API",
                @{ Endpoint = "$ApiBaseUrl/zone" })
        }

        return $response
    }
    catch [VeaException] {
        throw
    }
    catch {
        throw [VeaApiException]::new("Failed to retrieve zones: $($_.Exception.Message)",
            @{ Endpoint = "$ApiBaseUrl/zone" })
    }
}

# Ensure output directories exist
function Ensure-OutputDirectories {
    $outputDirs = @("output", "output\csv", "output\json")
    foreach ($dir in $outputDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

# Get traffic data for a specific zone with proper error handling
function Get-ZoneTrafficData {
    param(
        [string]$AccessToken,
        [string]$ZoneId,
        [string]$ZoneName,
        [string]$StartDate,
        [string]$EndDate,
        [string]$DateGrouping
    )

    try {
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type" = "application/json"
        }

        # Build URL for zone-specific traffic data
        $baseUrl = "$ApiBaseUrl/data/traffic"
        $params = @(
            "relativeDate=custom",
            "startDate=$StartDate",
            "endDate=$EndDate",
            "dateGroupings=$DateGrouping",
            "entityType=zone",
            "zoneId=$ZoneId"
        )

        $dataUrl = $baseUrl + "?" + ($params -join "&")

        Write-Host "  Querying zone: $ZoneName" -ForegroundColor Yellow
        Write-Host "  Zone ID: $ZoneId" -ForegroundColor Gray
        Write-Host "  URL: $dataUrl" -ForegroundColor DarkGray

        $response = Invoke-VeaRetry {
            Invoke-RestMethod -Uri $dataUrl -Method Get -Headers $headers -TimeoutSec 60
        }

        if ($response.results -and $response.results.Count -gt 0) {
            Write-Host "  Success: $($response.results.Count) records" -ForegroundColor Green
            return $response
        } else {
            Write-Host "  No data returned for this zone" -ForegroundColor Yellow
            return $null
        }
    }
    catch [VeaException] {
        Write-Host "  Error: $($_.Message)" -ForegroundColor Red
        return $null
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
    $CsvFile = "output\csv\${SafeName}_springshare_import.csv"
    $JsonFile = "output\json\${SafeName}_zone_data.json"

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
    
    # Show summary (with error suppression)
    try {
        $TotalEntries = ($DailyTotals.Values | Measure-Object -Property Entries -Sum -ErrorAction SilentlyContinue).Sum
        $TotalExits = ($DailyTotals.Values | Measure-Object -Property Exits -Sum -ErrorAction SilentlyContinue).Sum
    } catch {
        $TotalEntries = "N/A"
        $TotalExits = "N/A"
    }
    
    if ($GateMethod.ToLower() -ne "manual") {
        Write-Host "     $($DailyTotals.Count) days | Entries: $TotalEntries | Exits: $TotalExits" -ForegroundColor Gray
    } else {
        $TotalCount = $TotalEntries + $TotalExits
        Write-Host "     $($DailyTotals.Count) days | Total Count: $TotalCount" -ForegroundColor Gray
    }

    return $CsvFile
}

# Main execution with proper error handling
Write-Host ""
Write-Host "Step 1: Authentication" -ForegroundColor Yellow

try {
    $accessToken = Invoke-VeaSafe { Get-VEAAccessToken } "authentication"
    Write-Host "Authentication successful" -ForegroundColor Green
} catch {
    [VeaErrorHandler]::HandleException($_)
    exit 1
}

Write-Host ""
Write-Host "Step 2: Getting zones list" -ForegroundColor Yellow

try {
    $zones = Invoke-VeaSafe { Get-VEAZones -AccessToken $accessToken } "zone retrieval"
    Write-Host "Found $($zones.Count) zones" -ForegroundColor Green
} catch {
    [VeaErrorHandler]::HandleException($_)
    exit 1
}

    # Save zones data for reference
    $Zones | ConvertTo-Json -Depth 10 | Out-File -FilePath "output\json\vea_zones_list.json" -Encoding UTF8
    Write-Host "Saved zones list to: output\json\vea_zones_list.json" -ForegroundColor Gray

Write-Host ""
Write-Host "Step 3: Processing each zone" -ForegroundColor Yellow

$ProcessedZones = @()
$CreatedFiles = @()
$SuccessCount = 0

foreach ($zone in $zones) {
    Write-Host ""
    Write-Host "Processing Zone:" -ForegroundColor Cyan
    Write-Host "   Zone ID: $($zone.zoneId)" -ForegroundColor Gray
    Write-Host "   Zone Name: $($zone.name)" -ForegroundColor Gray
    Write-Host "   Sensor ID: $($zone.sensorId)" -ForegroundColor Gray

    # Get friendly sensor name
    $sensorName = $SensorNameMap[$zone.sensorId]
    if (-not $sensorName) {
        $sensorName = "Unknown Sensor $($zone.sensorId)"
        Write-Host "   Unknown sensor, using generic name" -ForegroundColor Yellow
    }

    Write-Host "   Friendly Name: $sensorName" -ForegroundColor Cyan

    # Get zone traffic data with error handling
    try {
        $zoneData = Get-ZoneTrafficData -AccessToken $accessToken -ZoneId $zone.zoneId -ZoneName $zone.name -StartDate $StartDate -EndDate $EndDate -DateGrouping $DateGrouping

        if ($zoneData) {
            $csvFile = Create-ZoneSpringshareCSV -ZoneData $zoneData -SensorName $sensorName -ZoneId $zone.zoneId -GateMethod $GateMethod

            if ($csvFile) {
                $CreatedFiles += $csvFile
                $SuccessCount++
            }

            $ProcessedZones += @{
                ZoneId = $zone.zoneId
                ZoneName = $zone.name
                SensorId = $zone.sensorId
                SensorName = $sensorName
                Success = $true
                CsvFile = $csvFile
            }
        } else {
            $ProcessedZones += @{
                ZoneId = $zone.zoneId
                ZoneName = $zone.name
                SensorId = $zone.sensorId
                SensorName = $sensorName
                Success = $false
            }
            Write-Host "   No data available for this zone" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "   Error processing zone $($zone.zoneId): $($_.Exception.Message)" -ForegroundColor Red
        $ProcessedZones += @{
            ZoneId = $zone.zoneId
            ZoneName = $zone.name
            SensorId = $zone.sensorId
            SensorName = $sensorName
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Final Summary
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "ZONE-BASED EXTRACTION COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

# Check if using automatic dates
$currentDate = [DateTime]::Now
$startOfYear = [DateTime]::new($currentDate.Year, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
$autoStartDate = $startOfYear.ToString("yyyy-MM-ddTHH:mm:ssZ")
$endOfDay = [DateTime]::new($currentDate.Year, $currentDate.Month, $currentDate.Day, 23, 59, 59, [DateTimeKind]::Utc)
$autoEndDate = $endOfDay.ToString("yyyy-MM-ddTHH:mm:ssZ")

$dateRangeType = if ($StartDate -eq $autoStartDate -and $EndDate -eq $autoEndDate) { " (Automatic: Current Year)" } else { " (Custom)" }

Write-Host "Date Range: $StartDate to $EndDate$dateRangeType" -ForegroundColor White
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