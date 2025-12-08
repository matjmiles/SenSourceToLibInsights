param(
    [Parameter(Mandatory=$true)]
    [string]$VeaJsonFile,
    
    [Parameter(Mandatory=$false)]
    [string]$GateMethod = "Bidirectional"
)

# Active sensors based on VEA reporting data
$ActiveSensors = @(
    @{ Name = "McKay Library Level 1 New Entrance"; Weight = 0.25; Type = "Entrance" },
    @{ Name = "McKay Library Level 3 Bridge"; Weight = 0.15; Type = "Bridge" },
    @{ Name = "McKay Library Level 2 Stairs"; Weight = 0.15; Type = "Stairs" },
    @{ Name = "McKay Library Level 3 Stairs"; Weight = 0.15; Type = "Stairs" },
    @{ Name = "McKay Library Level 1 Main Entrance 1"; Weight = 0.30; Type = "Entrance" }
)

Write-Host "=== VEA Data Splitter for Individual Sensors ===" -ForegroundColor Green
Write-Host "Source file: $VeaJsonFile" -ForegroundColor Cyan
Write-Host "Gate method: $GateMethod" -ForegroundColor Cyan
Write-Host "Active sensors: $($ActiveSensors.Count)" -ForegroundColor Cyan

# Verify file exists
if (-not (Test-Path $VeaJsonFile)) {
    Write-Host "❌ Error: File $VeaJsonFile not found!" -ForegroundColor Red
    exit 1
}

# Read and parse the VEA data
Write-Host "`n📁 Loading VEA data..." -ForegroundColor Yellow
try {
    $VeaData = Get-Content $VeaJsonFile -Raw | ConvertFrom-Json
    Write-Host "✅ Data loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error reading JSON file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify data structure
if (-not $VeaData.data.results) {
    Write-Host "❌ Error: No results found in VEA data!" -ForegroundColor Red
    exit 1
}

Write-Host "📊 Found $($VeaData.data.results.Count) hourly records" -ForegroundColor Cyan

# Group original data by date and sum
Write-Host "`n🔄 Processing aggregated data..." -ForegroundColor Yellow
$DailyTotals = @{}

foreach ($record in $VeaData.data.results) {
    if ($record.recordDate_hour_1) {
        $DateTime = [DateTime]$record.recordDate_hour_1
        $DateKey = $DateTime.ToString("yyyy-MM-dd")
        
        if (-not $DailyTotals.ContainsKey($DateKey)) {
            $DailyTotals[$DateKey] = @{
                TotalEntries = 0
                TotalExits = 0
            }
        }
        
        $DailyTotals[$DateKey].TotalEntries += [int]$record.sumins
        $DailyTotals[$DateKey].TotalExits += [int]$record.sumouts
    }
}

Write-Host "✅ Processed $($DailyTotals.Count) days of data" -ForegroundColor Green

# Show total summary
$GrandTotalEntries = ($DailyTotals.Values | Measure-Object -Property TotalEntries -Sum).Sum
$GrandTotalExits = ($DailyTotals.Values | Measure-Object -Property TotalExits -Sum).Sum
Write-Host "📈 Total traffic - Entries: $GrandTotalEntries, Exits: $GrandTotalExits" -ForegroundColor Cyan

# Create individual sensor CSV files
Write-Host "`n🏗️ Creating individual sensor CSV files..." -ForegroundColor Yellow

$CreatedFiles = @()

foreach ($sensor in $ActiveSensors) {
    Write-Host "`n  Processing: $($sensor.Name)" -ForegroundColor Cyan
    Write-Host "    Weight: $($sensor.Weight * 100)% | Type: $($sensor.Type)" -ForegroundColor Gray
    
    $SafeName = $sensor.Name -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
    $CsvFile = "${SafeName}_springshare_import.csv"
    
    # Create sensor-specific data by applying weight
    $SensorDailyData = @{}
    
    foreach ($date in $DailyTotals.Keys | Sort-Object) {
        $originalTotals = $DailyTotals[$date]
        
        # Apply weight to distribute the traffic
        $SensorEntries = [math]::Round($originalTotals.TotalEntries * $sensor.Weight)
        $SensorExits = [math]::Round($originalTotals.TotalExits * $sensor.Weight)
        
        $SensorDailyData[$date] = @{
            Entries = $SensorEntries
            Exits = $SensorExits
        }
    }
    
    # Create Springshare CSV format
    $CsvLines = @("date,gate_start,gate_end")
    
    foreach ($date in $SensorDailyData.Keys | Sort-Object) {
        $sensorTotals = $SensorDailyData[$date]
        
        switch ($GateMethod.ToLower()) {
            "bidirectional" {
                $CsvLines += "$date,$($sensorTotals.Entries),$($sensorTotals.Exits)"
            }
            "manual" {
                $total = $sensorTotals.Entries + $sensorTotals.Exits
                $CsvLines += "$date,$total,"
            }
            default {
                $CsvLines += "$date,$($sensorTotals.Entries),$($sensorTotals.Exits)"
            }
        }
    }
    
    # Save CSV file
    $CsvContent = $CsvLines -join "`n"
    [System.IO.File]::WriteAllText($CsvFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))
    
    $CreatedFiles += $CsvFile
    
    # Show sensor summary
    $SensorTotalEntries = ($SensorDailyData.Values | Measure-Object -Property Entries -Sum).Sum
    $SensorTotalExits = ($SensorDailyData.Values | Measure-Object -Property Exits -Sum).Sum
    
    Write-Host "    ✅ Created: $CsvFile" -ForegroundColor Green
    
    if ($GateMethod.ToLower() -ne "manual") {
        Write-Host "       📊 Entries: $SensorTotalEntries | Exits: $SensorTotalExits | Days: $($SensorDailyData.Count)" -ForegroundColor Gray
    } else {
        $SensorTotalCount = $SensorTotalEntries + $SensorTotalExits
        Write-Host "       📊 Total Count: $SensorTotalCount | Days: $($SensorDailyData.Count)" -ForegroundColor Gray
    }
    
    # Also create individual JSON file for reference
    $JsonFile = "${SafeName}_distributed_data.json"
    $SensorDataPackage = @{
        sensor_info = @{
            name = $sensor.Name
            weight_applied = $sensor.Weight
            sensor_type = $sensor.Type
            distribution_method = "Weighted proportional distribution from aggregated VEA data"
        }
        source_data = @{
            original_file = $VeaJsonFile
            total_entries_all_sensors = $GrandTotalEntries
            total_exits_all_sensors = $GrandTotalExits
            processing_date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        daily_data = $SensorDailyData
        springshare_format = @{
            gate_method = $GateMethod
            csv_file = $CsvFile
        }
    }
    
    $SensorDataPackage | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFile -Encoding UTF8
    Write-Host "       📄 Reference: $JsonFile" -ForegroundColor DarkGray
}

# Final summary
Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "🎯 DATA DISTRIBUTION COMPLETE" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

Write-Host "📊 Distribution Summary:" -ForegroundColor White
Write-Host "   Original total entries: $GrandTotalEntries" -ForegroundColor Gray
Write-Host "   Original total exits: $GrandTotalExits" -ForegroundColor Gray
Write-Host "   Distributed across: $($ActiveSensors.Count) sensors" -ForegroundColor Gray
Write-Host "   Method: Weighted proportional distribution" -ForegroundColor Gray

Write-Host "`n📁 Created Springshare Import Files:" -ForegroundColor Cyan
foreach ($file in $CreatedFiles) {
    Write-Host "   • $file" -ForegroundColor White
}

Write-Host "`n⚠️  IMPORTANT NOTE:" -ForegroundColor Yellow
Write-Host "   These files contain ESTIMATED data distributed from aggregated totals." -ForegroundColor Yellow
Write-Host "   The distribution weights are based on assumptions about traffic patterns:" -ForegroundColor Yellow
Write-Host "   • Main entrances: Higher traffic (30% and 25%)" -ForegroundColor Yellow
Write-Host "   • Stairs/Bridge: Lower traffic (15% each)" -ForegroundColor Yellow
Write-Host "   For actual individual sensor data, the VEA system would need to provide" -ForegroundColor Yellow
Write-Host "   sensor-specific breakdowns through their API or reporting interface." -ForegroundColor Yellow

Write-Host "`n✅ Files are ready for Springshare LibInsights import!" -ForegroundColor Green
Write-Host ""