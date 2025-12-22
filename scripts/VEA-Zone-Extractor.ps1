param(
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

# API Configuration
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Sensor ID to friendly name mapping
$SensorNameMap = @{
    "34e07466-3cd7-4e74-889a-b63891d056b5" = "McKay Library Level 3 Stairs"
    "5aeebd64-77eb-48c6-886b-9398703311d1" = "McKay Library Level 2 Stairs" 
    "508b24fa-eebf-4fa7-9ccd-0130334a99fb" = "McKay Library Level 3 Bridge"
    "24a57257-03c4-4220-acf7-267bc8c9c344" = "McKay Library Level 1 Main Entrance 1"
    "e2d3ed7a-0838-4fbf-a0e1-9b60ceaa49b4" = "McKay Library Level 1 New Entrance"
}

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

# Calculate automatic date range for current year
Write-Host "Calculating automatic date range for current year..." -ForegroundColor Cyan
$dateRange = Get-AutomaticDateRange
$StartDate = $dateRange.StartDate
$EndDate = $dateRange.EndDate
Write-Host "Auto Start Date: $StartDate" -ForegroundColor Gray
Write-Host "Auto End Date: $EndDate" -ForegroundColor Gray

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

# Get access token from VEA API
function Get-VEAAccessToken {
    $authUrl = "https://auth.sensourceinc.com/oauth/token"

    $authBody = @{
        grant_type = "client_credentials"
        client_id = $ClientId
        client_secret = $ClientSecret
    } | ConvertTo-Json

    $headers = @{ "Content-Type" = "application/json" }

    $tokenResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Body $authBody -Headers $headers -TimeoutSec 30

    if (-not $tokenResponse.access_token) {
        throw [VeaAuthenticationException]::new("Failed to obtain access token from VEA API")
    }

    return $tokenResponse.access_token
}

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
    $outputDirs = @("output", "output\csv", "output\csv\occupancy", "output\csv\gate_counts", "output\json")
    foreach ($dir in $outputDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

# Map sensor names to new naming convention
function Get-FriendlyFileName {
    param([string]$SensorName)
    
    switch ($SensorName) {
        "McKay Library Level 1 Main Entrance 1" { return "West Wing Level 1 East Side" }
        "McKay Library Level 1 New Entrance" { return "West Wing Level 1 West Side" }
        "McKay Library Level 2 Stairs" { return "West Wing Level 2 Stairs" }
        "McKay Library Level 3 Bridge" { return "West Wing Level 3 Bridge" }
        "McKay Library Level 3 Stairs" { return "West Wing Level 3 Stairs" }
        default { return ($SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_') }
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

    $FriendlyName = Get-FriendlyFileName -SensorName $SensorName
    $SafeName = $SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
    $CsvFile = "output\csv\occupancy\Occupancy ${FriendlyName}.csv"
    $GateCountsFile = "output\csv\gate_counts\Gate Count ${FriendlyName}.csv"
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

    # Create occupancy CSV format (hourly with date/time and gate_start/gate_end)
    $CsvLines = @("date,gate_start,gate_end")
    
    # Process hourly records directly (no daily aggregation)
    foreach ($record in $ZoneData.results) {
        # CRITICAL: Only process records for the specific zone we requested
        if ($record.zoneId -ne $ZoneId) {
            continue  # Skip records from other zones
        }
        
        # Extract date/time from record
        $dateTime = $null
        if ($record.recordDate_hour_1) {
            $dateTime = [DateTime]$record.recordDate_hour_1
        } elseif ($record.recordDate_day_1) {
            $dateTime = [DateTime]$record.recordDate_day_1
        } elseif ($record.recordDate_month_1) {
            $dateTime = [DateTime]$record.recordDate_month_1
        }
        
        if ($dateTime) {
            # Use full date/time for hourly records
            $hourlyDateKey = $dateTime.ToString("yyyy-MM-dd HH:mm")
            
            # Get entry and exit counts for this hour
            $entryCount = if ($record.sumins) { [int]$record.sumins } else { 0 }
            $exitCount = if ($record.sumouts) { [int]$record.sumouts } else { 0 }
            
            switch ($GateMethod.ToLower()) {
                "bidirectional" {
                    $CsvLines += "$hourlyDateKey,$entryCount,$exitCount"
                }
                "manual" {
                    $total = $entryCount + $exitCount
                    $CsvLines += "$hourlyDateKey,$total,"
                }
                default {
                    $CsvLines += "$hourlyDateKey,$entryCount,$exitCount"
                }
            }
        }
    }

    if ($CsvLines.Count -le 1) {
        Write-Host "  No valid hourly records found" -ForegroundColor Yellow
        return $null
    }

    # Save occupancy CSV file (original format with gate_start and gate_end)
    $CsvContent = $CsvLines -join "`n"
    [System.IO.File]::WriteAllText($CsvFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "  Created Occupancy CSV: $CsvFile" -ForegroundColor Green

    # Create gate_counts CSV file (hourly format with date and gate_start)
    $GateCountsLines = @("date,gate_start")
    
    # Process hourly records directly (no daily aggregation for gate_counts)
    foreach ($record in $ZoneData.results) {
        # Filter to only this zone's records
        if ($record.zoneId -ne $ZoneId) {
            continue
        }
        
        # Extract date/time from record
        $dateTime = $null
        if ($record.recordDate_hour_1) {
            $dateTime = [DateTime]$record.recordDate_hour_1
        } elseif ($record.recordDate_day_1) {
            $dateTime = [DateTime]$record.recordDate_day_1
        } elseif ($record.recordDate_month_1) {
            $dateTime = [DateTime]$record.recordDate_month_1
        }
        
        if ($dateTime) {
            # Use full date/time for hourly records
            $hourlyDateKey = $dateTime.ToString("yyyy-MM-dd HH:mm")
            
            # Get entry count for this hour
            $entryCount = if ($record.sumins) { [int]$record.sumins } else { 0 }
            
            $GateCountsLines += "$hourlyDateKey,$entryCount"
        }
    }

    # Save gate_counts CSV file
    $GateCountsContent = $GateCountsLines -join "`n"
    [System.IO.File]::WriteAllText($GateCountsFile, $GateCountsContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "  Created Gate Counts CSV: $GateCountsFile" -ForegroundColor Green
    
    # Show summary
    $hourlyRecords = $CsvLines.Count - 1  # Subtract header line
    Write-Host "     $hourlyRecords hourly records processed" -ForegroundColor Gray

    return @{
        OccupancyFile = $CsvFile
        GateCountsFile = $GateCountsFile
    }
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
Write-Host "Step 3: Creating output directories and processing zones" -ForegroundColor Yellow

# Ensure all output directories exist
Ensure-OutputDirectories

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
            $csvResult = Create-ZoneSpringshareCSV -ZoneData $zoneData -SensorName $sensorName -ZoneId $zone.zoneId -GateMethod $GateMethod

            if ($csvResult -and $csvResult.OccupancyFile) {
                $CreatedFiles += $csvResult.OccupancyFile
                if ($csvResult.GateCountsFile) {
                    $CreatedFiles += $csvResult.GateCountsFile
                }
                $SuccessCount++
            }

            $ProcessedZones += @{
                ZoneId = $zone.zoneId
                ZoneName = $zone.name
                SensorId = $zone.sensorId
                SensorName = $sensorName
                Success = $true
                OccupancyFile = $csvResult.OccupancyFile
                GateCountsFile = $csvResult.GateCountsFile
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
    Write-Host "Created Files:" -ForegroundColor Cyan
    
    # Separate occupancy and gate_counts files
    $OccupancyFiles = $CreatedFiles | Where-Object { $_ -like "*\occupancy\*" }
    $GateCountsFiles = $CreatedFiles | Where-Object { $_ -like "*\gate_counts\*" }
    
    if ($OccupancyFiles) {
        Write-Host "   Occupancy Files (date, gate_start, gate_end - HOURLY):" -ForegroundColor Yellow
        foreach ($file in $OccupancyFiles) {
            Write-Host "     $file" -ForegroundColor White
        }
    }
    
    if ($GateCountsFiles) {
        Write-Host "   Gate Counts Files (date, gate_start - HOURLY):" -ForegroundColor Yellow
        foreach ($file in $GateCountsFiles) {
            Write-Host "     $file" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "Ready for analysis and import!" -ForegroundColor Green
    Write-Host "All files now contain HOURLY data for detailed traffic analysis" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "WARNING: No sensor data was successfully extracted!" -ForegroundColor Yellow
}

Write-Host ""