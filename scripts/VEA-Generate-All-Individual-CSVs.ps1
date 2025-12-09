param(
    [Parameter(Mandatory=$false)]
    [string]$GateMethod = "Bidirectional"
)

# Suppress non-critical errors for better user experience
$ErrorActionPreference = "SilentlyContinue"

Write-Host "VEA Individual Sensor CSV Generator" -ForegroundColor Green
Write-Host "Processing all zone JSON files to create individual sensor CSVs" -ForegroundColor Cyan
Write-Host "Gate Method: $GateMethod" -ForegroundColor Cyan

# Find all zone data JSON files
$ZoneJsonFiles = Get-ChildItem -Filter "*_zone_data.json"

if ($ZoneJsonFiles.Count -eq 0) {
    Write-Host "No zone JSON files found! Please run the zone extractor first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Found $($ZoneJsonFiles.Count) zone JSON files to process" -ForegroundColor Yellow

$CreatedFiles = @()
$ProcessedCount = 0

foreach ($jsonFile in $ZoneJsonFiles) {
    $ProcessedCount++
    Write-Host ""
    Write-Host "[$ProcessedCount/$($ZoneJsonFiles.Count)] Processing: $($jsonFile.Name)" -ForegroundColor Cyan
    
    try {
        # Read zone data
        $ZoneDataPackage = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
        
        # Extract zone info
        $RequestedZoneId = $ZoneDataPackage.zone_info.zone_id
        $SensorName = $ZoneDataPackage.zone_info.sensor_name
        $AllResults = $ZoneDataPackage.raw_data.results
        
        Write-Host "  Sensor: $SensorName" -ForegroundColor Gray
        Write-Host "  Zone ID: $RequestedZoneId" -ForegroundColor Gray
        Write-Host "  Total records: $($AllResults.Count)" -ForegroundColor Gray
        
        # Filter results to only the requested zone
        $ZoneSpecificResults = $AllResults | Where-Object { $_.zoneId -eq $RequestedZoneId }
        
        Write-Host "  Zone-specific records: $($ZoneSpecificResults.Count)" -ForegroundColor Green
        
        if ($ZoneSpecificResults.Count -eq 0) {
            Write-Host "  No records for this zone - skipping" -ForegroundColor Yellow
            continue
        }
        
        # Group by date and aggregate
        $DailyTotals = @{}
        
        foreach ($record in $ZoneSpecificResults) {
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
            Write-Host "  No daily data - skipping" -ForegroundColor Yellow
            continue
        }
        
        # Create Springshare CSV
        $SafeName = $SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
        $CsvFile = "${SafeName}_individual_springshare_import.csv"
        
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
        
        $CreatedFiles += $CsvFile
        
        # Calculate totals (with error suppression)
        try {
            $TotalEntries = ($DailyTotals.Values | Measure-Object -Property Entries -Sum -ErrorAction SilentlyContinue).Sum
            $TotalExits = ($DailyTotals.Values | Measure-Object -Property Exits -Sum -ErrorAction SilentlyContinue).Sum
        } catch {
            $TotalEntries = "N/A"
            $TotalExits = "N/A"
        }
        
        Write-Host "  Created: $CsvFile" -ForegroundColor Green
        
        if ($GateMethod.ToLower() -ne "manual") {
            Write-Host "  Summary: $($DailyTotals.Count) days | Entries: $TotalEntries | Exits: $TotalExits" -ForegroundColor Gray
        } else {
            $TotalCount = $TotalEntries + $TotalExits
            Write-Host "  Summary: $($DailyTotals.Count) days | Total Count: $TotalCount" -ForegroundColor Gray
        }
        
    }
    catch {
        Write-Host "  Error processing $($jsonFile.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Final Summary
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "INDIVIDUAL SENSOR CSV GENERATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "Processed: $ProcessedCount zone files" -ForegroundColor White
Write-Host "Created: $($CreatedFiles.Count) individual sensor CSV files" -ForegroundColor White
Write-Host "Gate Method: $GateMethod" -ForegroundColor White

if ($CreatedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Created Individual Sensor CSV Files:" -ForegroundColor Cyan
    foreach ($file in $CreatedFiles) {
        Write-Host "  $file" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Each CSV file contains REAL individual sensor data from VEA zones." -ForegroundColor Green
    Write-Host "These files are ready for Springshare LibInsights import!" -ForegroundColor Green
    
    # Clean up old files (the ones with identical data)
    Write-Host ""
    Write-Host "Cleaning up duplicate files..." -ForegroundColor Yellow
    Get-ChildItem -Filter "*_springshare_import.csv" | Where-Object { $_.Name -notlike "*_individual_*" } | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "  Removed: $($_.Name)" -ForegroundColor Gray
    }
    
} else {
    Write-Host ""
    Write-Host "WARNING: No CSV files were created!" -ForegroundColor Yellow
}

Write-Host ""