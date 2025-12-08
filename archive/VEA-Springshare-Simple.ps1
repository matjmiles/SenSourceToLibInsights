# VEA to Springshare LibInsights Converter - Fixed Version
param(
    [Parameter(Mandatory=$true)]
    [string]$VeaJsonFile,
    
    [Parameter(Mandatory=$false)]
    [string]$GateMethod = "Bidirectional"
)

Write-Host "=== VEA to Springshare Converter ===" -ForegroundColor Green
Write-Host "Input: $VeaJsonFile" -ForegroundColor Cyan
Write-Host "Gate Method: $GateMethod" -ForegroundColor Cyan

# Generate output filename
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($VeaJsonFile)
$OutputFile = "${BaseName}_springshare_import.csv"

# Load VEA data
Write-Host "`nLoading VEA data..." -ForegroundColor Yellow
$VeaData = Get-Content $VeaJsonFile | ConvertFrom-Json
$DataRecords = $VeaData.data.results
Write-Host "Loaded $($DataRecords.Count) hourly records" -ForegroundColor Green

# Convert to daily aggregates for Springshare
Write-Host "Converting to daily totals..." -ForegroundColor Yellow

# Group by date and aggregate
$DailyTotals = @{}

foreach ($record in $DataRecords) {
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

# Create CSV content with exact Springshare format
Write-Host "Creating Springshare CSV..." -ForegroundColor Yellow

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

Write-Host "CSV file created: $OutputFile" -ForegroundColor Green

# Show summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Daily records created: $($SpringshareRecords.Count)" -ForegroundColor White
Write-Host "Date range: $($SpringshareRecords[0].date) to $($SpringshareRecords[-1].date)" -ForegroundColor White
Write-Host "Gate method: $GateMethod" -ForegroundColor White

if ($GateMethod.ToLower() -ne "manual") {
    $TotalStart = ($SpringshareRecords | Measure-Object -Property gate_start -Sum).Sum
    $TotalEnd = ($SpringshareRecords | Measure-Object -Property gate_end -Sum).Sum  
    Write-Host "Total entries: $TotalStart" -ForegroundColor White
    Write-Host "Total exits: $TotalEnd" -ForegroundColor White
} else {
    $TotalCount = ($SpringshareRecords | Measure-Object -Property gate_start -Sum).Sum
    Write-Host "Total count: $TotalCount" -ForegroundColor White
}

# Show file preview
Write-Host "`nFile preview:" -ForegroundColor Yellow
Get-Content $OutputFile | Select-Object -First 5 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

Write-Host "`n=== Ready for Springshare Import ===" -ForegroundColor Green