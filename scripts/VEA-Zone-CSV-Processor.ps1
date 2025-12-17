param(
    [Parameter(Mandatory=$true)]
    [string]$ZoneJsonFile,
    
    [Parameter(Mandatory=$false)]
    [string]$GateMethod = "Bidirectional"
)

# Sensor ID to friendly name mapping
$SensorNameMap = @{
    "34e07466-3cd7-4e74-889a-b63891d056b5" = "McKay Library Level 3 Stairs"
    "5aeebd64-77eb-48c6-886b-9398703311d1" = "McKay Library Level 2 Stairs" 
    "508b24fa-eebf-4fa7-9ccd-0130334a99fb" = "McKay Library Level 3 Bridge"
    "24a57257-03c4-4220-acf7-267bc8c9c344" = "McKay Library Level 1 Main Entrance 1"
    "e2d3ed7a-0838-4fbf-a0e1-9b60ceaa49b4" = "McKay Library Level 1 New Entrance"
}

Write-Host "VEA Zone Data Processor - Individual Sensor CSV Creator" -ForegroundColor Green
Write-Host "Processing file: $ZoneJsonFile" -ForegroundColor Cyan
Write-Host "Gate method: $GateMethod" -ForegroundColor Cyan

# Read zone data
if (-not (Test-Path $ZoneJsonFile)) {
    Write-Host "Error: File $ZoneJsonFile not found!" -ForegroundColor Red
    exit 1
}

try {
    $ZoneDataPackage = Get-Content $ZoneJsonFile -Raw | ConvertFrom-Json
    Write-Host "Zone data loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "Error reading JSON file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Extract zone info
$RequestedZoneId = $ZoneDataPackage.zone_info.zone_id
$SensorName = $ZoneDataPackage.zone_info.sensor_name
$AllResults = $ZoneDataPackage.raw_data.results

Write-Host ""
Write-Host "Zone Info:" -ForegroundColor Yellow
Write-Host "  Requested Zone ID: $RequestedZoneId" -ForegroundColor Gray
Write-Host "  Sensor Name: $SensorName" -ForegroundColor Gray
Write-Host "  Total records in file: $($AllResults.Count)" -ForegroundColor Gray

# Filter results to only the requested zone
$ZoneSpecificResults = $AllResults | Where-Object { $_.zoneId -eq $RequestedZoneId }

Write-Host "  Zone-specific records: $($ZoneSpecificResults.Count)" -ForegroundColor Cyan

if ($ZoneSpecificResults.Count -eq 0) {
    Write-Host "No records found for the requested zone!" -ForegroundColor Red
    exit 1
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

Write-Host "  Daily aggregation complete: $($DailyTotals.Count) days" -ForegroundColor Green

# Create Springshare CSV
$SafeName = $SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
$CsvFile = "output\csv\${SafeName}_individual_springshare_import.csv"

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

Write-Host ""
Write-Host "Created: $CsvFile" -ForegroundColor Green

# Show summary
$TotalEntries = ($DailyTotals.Values | Measure-Object -Property Entries -Sum).Sum
$TotalExits = ($DailyTotals.Values | Measure-Object -Property Exits -Sum).Sum

if ($GateMethod.ToLower() -ne "manual") {
    Write-Host "Summary: $($DailyTotals.Count) days | Entries: $TotalEntries | Exits: $TotalExits" -ForegroundColor Cyan
} else {
    $TotalCount = $TotalEntries + $TotalExits
    Write-Host "Summary: $($DailyTotals.Count) days | Total Count: $TotalCount" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Individual sensor CSV file created successfully!" -ForegroundColor Green
Write-Host "This file contains REAL data for only the $SensorName sensor." -ForegroundColor Green
Write-Host ""