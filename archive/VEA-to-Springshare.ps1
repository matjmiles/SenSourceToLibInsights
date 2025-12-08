# VEA to Springshare LibInsights Converter
# Converts VEA JSON data to Springshare's exact CSV format requirement

param(
    [Parameter(Mandatory=$true)]
    [string]$VeaJsonFile,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "",
    
    [Parameter(Mandatory=$false)]
    [string]$GateMethod = "Bidirectional"  # Bidirectional, Unidirectional, or Manual
)

Write-Host "=== VEA to Springshare LibInsights Converter ===" -ForegroundColor Green
Write-Host "Input: $VeaJsonFile" -ForegroundColor Cyan
Write-Host "Gate Method: $GateMethod" -ForegroundColor Cyan

# Validate input file
if (-not (Test-Path $VeaJsonFile)) {
    Write-Host "❌ VEA JSON file not found: $VeaJsonFile" -ForegroundColor Red
    exit 1
}

# Generate output filename if not provided
if ($OutputFile -eq "") {
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($VeaJsonFile)
    $OutputFile = "${BaseName}_springshare_import.csv"
}

# Load VEA data
try {
    Write-Host "Loading VEA data..." -ForegroundColor Yellow
    $VeaData = Get-Content $VeaJsonFile | ConvertFrom-Json
    
    # Extract the actual data records
    if ($VeaData.data.results) {
        $DataRecords = $VeaData.data.results
    } elseif ($VeaData.data -is [array]) {
        $DataRecords = $VeaData.data
    } else {
        throw "Unknown VEA data structure"
    }
    
    Write-Host "✓ Loaded $($DataRecords.Count) records" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to load VEA data: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Convert to Springshare format
Write-Host "Converting to Springshare format..." -ForegroundColor Yellow

$SpringshareData = @()

foreach ($record in $DataRecords) {
    if ($record.recordDate_hour_1 -and ($record.sumins -gt 0 -or $record.sumouts -gt 0)) {
        # Parse the date from VEA format (ISO 8601 UTC) to local date
        $DateTime = [DateTime]$record.recordDate_hour_1
        $LocalDate = $DateTime.ToString("yyyy-MM-dd")
        
        # Create Springshare record based on gate method
        switch ($GateMethod.ToLower()) {
            "bidirectional" {
                # For bidirectional gates, provide both start and end values
                # Assuming gate_start = entries, gate_end = exits
                $SpringshareData += [PSCustomObject]@{
                    "date" = $LocalDate
                    "gate_start" = $record.sumins
                    "gate_end" = $record.sumouts
                }
            }
            "unidirectional" {
                # For unidirectional, still provide both values but they represent different meaning
                # Total activity as start, net flow as end (adjust as needed)
                $SpringshareData += [PSCustomObject]@{
                    "date" = $LocalDate
                    "gate_start" = ($record.sumins + $record.sumouts)  # Total activity
                    "gate_end" = ($record.sumins - $record.sumouts)    # Net flow
                }
            }
            "manual" {
                # For manual method, only gate_start is used (total visits)
                $SpringshareData += [PSCustomObject]@{
                    "date" = $LocalDate
                    "gate_start" = ($record.sumins + $record.sumouts)  # Total activity
                    "gate_end" = ""  # Empty for manual method
                }
            }
            default {
                throw "Invalid gate method: $GateMethod. Use Bidirectional, Unidirectional, or Manual"
            }
        }
    }
}

# Group by date and sum the values (since we have hourly data but Springshare wants daily)
Write-Host "Aggregating hourly data to daily totals..." -ForegroundColor Gray

$DailyData = $SpringshareData | Group-Object -Property date | ForEach-Object {
    $DateGroup = $_.Group
    
    if ($GateMethod.ToLower() -eq "manual") {
        [PSCustomObject]@{
            "date" = $_.Name
            "gate_start" = ($DateGroup | Measure-Object -Property gate_start -Sum).Sum
            "gate_end" = ""
        }
    } else {
        [PSCustomObject]@{
            "date" = $_.Name  
            "gate_start" = ($DateGroup | Measure-Object -Property gate_start -Sum).Sum
            "gate_end" = ($DateGroup | Measure-Object -Property gate_end -Sum).Sum
        }
    }
} | Sort-Object date

Write-Host "✓ Aggregated to $($DailyData.Count) daily records" -ForegroundColor Green

# Export to CSV with exact Springshare format
Write-Host "Exporting to Springshare CSV format..." -ForegroundColor Yellow

# Create CSV content manually to ensure exact format
$CsvContent = "date,gate_start,gate_end`n"

foreach ($record in $DailyData) {
    if ($GateMethod.ToLower() -eq "manual") {
        $CsvContent += "$($record.date),$($record.gate_start),`n"
    } else {
        $CsvContent += "$($record.date),$($record.gate_start),$($record.gate_end)`n"
    }
}

# Save as UTF-8 without BOM (as required by Springshare)
[System.IO.File]::WriteAllText($OutputFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))

Write-Host "✓ Springshare CSV file created: $OutputFile" -ForegroundColor Green

# Show summary
Write-Host "`n=== Conversion Summary ===" -ForegroundColor Cyan
Write-Host "Source Records (hourly): $($DataRecords.Count)" -ForegroundColor White
Write-Host "Output Records (daily): $($DailyData.Count)" -ForegroundColor White
Write-Host "Gate Method: $GateMethod" -ForegroundColor White
Write-Host "Output File: $OutputFile" -ForegroundColor White
Write-Host "Encoding: UTF-8 without BOM" -ForegroundColor White

if ($DailyData.Count -gt 0) {
    $FirstDate = $DailyData[0].date
    $LastDate = $DailyData[-1].date
    Write-Host "Date Range: $FirstDate to $LastDate" -ForegroundColor White
    
    if ($GateMethod.ToLower() -ne "manual") {
        $TotalStart = ($DailyData | Measure-Object -Property gate_start -Sum).Sum
        $TotalEnd = ($DailyData | Measure-Object -Property gate_end -Sum).Sum
        Write-Host "Total Gate Start: $TotalStart" -ForegroundColor White
        Write-Host "Total Gate End: $TotalEnd" -ForegroundColor White
    } else {
        $TotalCount = ($DailyData | Measure-Object -Property gate_start -Sum).Sum
        Write-Host "Total Count: $TotalCount" -ForegroundColor White
    }
}

# Show preview
Write-Host "`nFile Preview:" -ForegroundColor Yellow
Get-Content $OutputFile | Select-Object -First 5 | ForEach-Object { 
    Write-Host $_ -ForegroundColor Gray 
}

Write-Host "`n=== Ready for Springshare Import ===" -ForegroundColor Green
Write-Host "✓ CSV format matches Springshare template" -ForegroundColor White
Write-Host "✓ UTF-8 encoding without BOM" -ForegroundColor White
Write-Host "✓ Comma separated records" -ForegroundColor White
Write-Host "✓ Each record on new line" -ForegroundColor White
Write-Host "✓ Daily aggregation completed" -ForegroundColor White

Write-Host "`nImport Instructions:" -ForegroundColor Cyan
Write-Host "1. Log into Springshare LibInsights" -ForegroundColor White
Write-Host "2. Navigate to data import/upload section" -ForegroundColor White
Write-Host "3. Upload file: $OutputFile" -ForegroundColor White
Write-Host "4. Select gate method: $GateMethod" -ForegroundColor White