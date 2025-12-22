# VEA JSON to Pivot Report Generator
# Processes existing zone JSON files and creates a pivot CSV report
# Format: Location names as rows, dates as columns, sumins as values

param(
    [string]$JsonDirectory = "output\json",
    [string]$OutputFile = "output\csv\gate_counts\VEA_Daily_Sumins_Pivot_Report.csv"
)

Write-Host "VEA JSON to Pivot Report Generator" -ForegroundColor Green
Write-Host "Processing JSON files from: $JsonDirectory" -ForegroundColor Cyan

# Find all zone data JSON files
$JsonFiles = Get-ChildItem -Path $JsonDirectory -Filter "*_zone_data.json" -ErrorAction SilentlyContinue

if (-not $JsonFiles -or $JsonFiles.Count -eq 0) {
    Write-Error "No zone data JSON files found in $JsonDirectory"
    Write-Host "Make sure you've run the VEA-Zone-Extractor.ps1 script first to generate the JSON files."
    exit 1
}

Write-Host "Found $($JsonFiles.Count) JSON files to process" -ForegroundColor Yellow

# Data structure: [Location][Date] = sumins value
$LocationData = @{}
$AllDates = @()

# Process each JSON file
foreach ($jsonFile in $JsonFiles) {
    Write-Host "Processing: $($jsonFile.Name)" -ForegroundColor Gray
    
    try {
        # Load JSON data
        $jsonContent = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json
        
        # Extract location name from sensor_name
        $locationName = $jsonContent.zone_info.sensor_name
        if (-not $locationName) {
            Write-Warning "No sensor_name found in $($jsonFile.Name), skipping"
            continue
        }
        
        # Clean up location name for CSV
        $locationName = $locationName -replace "McKay Library ", ""
        
        Write-Host "  Location: $locationName" -ForegroundColor White
        
        # Initialize location data
        if (-not $LocationData.ContainsKey($locationName)) {
            $LocationData[$locationName] = @{}
        }
        
        # Get the zone ID for filtering
        $zoneId = $jsonContent.zone_info.zone_id
        
        # Process hourly records and aggregate to daily totals
        $dailyTotals = @{}
        
        foreach ($record in $jsonContent.raw_data.results) {
            # Filter to only this zone's records
            if ($record.zoneId -ne $zoneId) {
                continue
            }
            
            # Extract date from record
            $dateTime = $null
            if ($record.recordDate_hour_1) {
                $dateTime = [DateTime]$record.recordDate_hour_1
            } elseif ($record.recordDate_day_1) {
                $dateTime = [DateTime]$record.recordDate_day_1
            } elseif ($record.recordDate_month_1) {
                $dateTime = [DateTime]$record.recordDate_month_1
            }
            
            if ($dateTime) {
                $dateKey = $dateTime.ToString("yyyy-MM-dd")
                
                # Initialize daily total if needed
                if (-not $dailyTotals.ContainsKey($dateKey)) {
                    $dailyTotals[$dateKey] = 0
                }
                
                # Add sumins to daily total
                if ($record.sumins) {
                    $dailyTotals[$dateKey] += [int]$record.sumins
                }
                
                # Track all dates
                if ($dateKey -notin $AllDates) {
                    $AllDates += $dateKey
                }
            }
        }
        
        # Store daily totals for this location
        foreach ($date in $dailyTotals.Keys) {
            $LocationData[$locationName][$date] = $dailyTotals[$date]
        }
        
        Write-Host "     Processed $($dailyTotals.Count) days of data" -ForegroundColor Gray
        
    } catch {
        Write-Warning "Error processing $($jsonFile.Name): $($_.Exception.Message)"
    }
}

if ($LocationData.Count -eq 0) {
    Write-Error "No valid location data found to process"
    exit 1
}

# Sort dates chronologically
$AllDates = $AllDates | Sort-Object

Write-Host ""
Write-Host "Creating pivot CSV report..." -ForegroundColor Cyan
Write-Host "Locations: $($LocationData.Keys -join ', ')" -ForegroundColor White
Write-Host "Date Range: $($AllDates[0]) to $($AllDates[-1])" -ForegroundColor White
Write-Host "Total Days: $($AllDates.Count)" -ForegroundColor White

# Create CSV headers - IMPORTANT: Empty first cell, then dates
$csvHeaders = @("") + $AllDates
$csvLines = @($csvHeaders -join ",")

# Create CSV rows for each location
foreach ($location in $LocationData.Keys | Sort-Object) {
    $row = @($location)  # Location name in first column
    
    foreach ($date in $AllDates) {
        $value = if ($LocationData[$location].ContainsKey($date)) {
            $LocationData[$location][$date]
        } else {
            0
        }
        $row += $value
    }
    
    $csvLines += ($row -join ",")
}

# Ensure output directory exists
$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Save CSV file
$csvContent = $csvLines -join "`n"
[System.IO.File]::WriteAllText($OutputFile, $csvContent, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "SUCCESS: Pivot report created!" -ForegroundColor Green
Write-Host "Output file: $OutputFile" -ForegroundColor Cyan
Write-Host "Format: Locations as rows, dates as columns, daily sumins as values" -ForegroundColor Gray

# Show sample of data
Write-Host ""
Write-Host "Sample Data Preview:" -ForegroundColor Yellow
$previewLines = $csvLines | Select-Object -First 6
foreach ($line in $previewLines) {
    if ($line.Length -gt 100) {
        Write-Host "  $($line.Substring(0, 97))..." -ForegroundColor White
    } else {
        Write-Host "  $line" -ForegroundColor White
    }
}

if ($csvLines.Count -gt 6) {
    Write-Host "  ... ($($csvLines.Count - 6) more rows)" -ForegroundColor Gray
}

Write-Host ""