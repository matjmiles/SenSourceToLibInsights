# VEA to CSV Converter - Fixed Version  
# Converts VEA JSON data to CSV format for library systems

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

Write-Host "=== VEA to CSV Converter ===" -ForegroundColor Green

# Check if input file exists
if (-not (Test-Path $InputFile)) {
    Write-Host "Input file not found: $InputFile" -ForegroundColor Red
    exit 1
}

# Load VEA data
try {
    $VeaData = Get-Content $InputFile | ConvertFrom-Json
    Write-Host "Loaded VEA data successfully" -ForegroundColor Green
    
    # Handle different JSON structures
    if ($VeaData.data.results) {
        $DataRecords = $VeaData.data.results
        Write-Host "Using VEA API response format" -ForegroundColor Gray
    } elseif ($VeaData.data -is [array]) {
        $DataRecords = $VeaData.data  
        Write-Host "Using array format" -ForegroundColor Gray
    } else {
        Write-Host "Unknown data structure" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Records found: $($DataRecords.Count)" -ForegroundColor White
}
catch {
    Write-Host "Failed to load VEA data: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Generate output filename
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$OutputFile = "${BaseName}_for_springshare.csv"

Write-Host "`nConverting to CSV format..." -ForegroundColor Yellow

# Create CSV with library statistics columns
$CsvData = @()
$RecordCount = 0

foreach ($record in $DataRecords) {
    if ($record.recordDate_hour_1) {
        $DateTime = [DateTime]$record.recordDate_hour_1
        $CsvData += [PSCustomObject]@{
            "Date" = $DateTime.ToString("yyyy-MM-dd")
            "Time" = $DateTime.ToString("HH:mm:ss") 
            "DateTime" = $record.recordDate_hour_1
            "Hour" = $DateTime.Hour
            "DayOfWeek" = $DateTime.DayOfWeek.ToString()
            "Entries" = $record.sumins
            "Exits" = $record.sumouts
            "NetFlow" = ($record.sumins - $record.sumouts)
            "TotalActivity" = ($record.sumins + $record.sumouts)
            "Source" = "VEA"
            "DataType" = "traffic"
        }
        $RecordCount++
    }
}

# Export to CSV
$CsvData | Export-Csv -Path $OutputFile -NoTypeInformation
Write-Host "CSV file created: $OutputFile" -ForegroundColor Green

# Show summary
Write-Host "`nConversion Summary:" -ForegroundColor Green
Write-Host "Input Records: $RecordCount" -ForegroundColor White
Write-Host "Output File: $OutputFile" -ForegroundColor White
Write-Host "File Size: $([Math]::Round((Get-Item $OutputFile).Length / 1KB, 2)) KB" -ForegroundColor White

# Show sample
Write-Host "`nFirst 3 rows of CSV:" -ForegroundColor Yellow
Get-Content $OutputFile | Select-Object -First 4 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# Show some statistics
if ($CsvData.Count -gt 0) {
    $TotalEntries = ($CsvData | Measure-Object -Property Entries -Sum).Sum
    $TotalExits = ($CsvData | Measure-Object -Property Exits -Sum).Sum
    $DateRange = "$($CsvData[0].Date) to $($CsvData[-1].Date)"
    
    Write-Host "`nData Summary:" -ForegroundColor Cyan
    Write-Host "Date Range: $DateRange" -ForegroundColor White
    Write-Host "Total Entries: $TotalEntries" -ForegroundColor White
    Write-Host "Total Exits: $TotalExits" -ForegroundColor White
    Write-Host "Net Flow: $($TotalEntries - $TotalExits)" -ForegroundColor White
}

Write-Host "`n=== Possible Springshare Import Formats ===" -ForegroundColor Cyan
Write-Host "1. CSV (created) - Most common for manual imports" -ForegroundColor White
Write-Host "2. Contact Springshare about LibInsights import requirements" -ForegroundColor White
Write-Host "3. Common library statistics formats:" -ForegroundColor White
Write-Host "   - Date/Time columns for temporal data" -ForegroundColor Gray
Write-Host "   - Numeric columns for counts/metrics" -ForegroundColor Gray
Write-Host "   - Standard library terminology (visits, entries, etc.)" -ForegroundColor Gray

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Log into LibInsights and look for 'Import' or 'Upload' options" -ForegroundColor White
Write-Host "2. Try importing the CSV file manually" -ForegroundColor White  
Write-Host "3. Contact Springshare support: support@springshare.com" -ForegroundColor White