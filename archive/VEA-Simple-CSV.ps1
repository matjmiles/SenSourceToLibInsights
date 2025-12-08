# VEA to CSV Converter - Simple Version
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
    Write-Host "Data Type: $($VeaData.parameters.data_type)" -ForegroundColor White
    Write-Host "Records: $($VeaData.data.Count)" -ForegroundColor White
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
foreach ($record in $VeaData.data) {
    $DateTime = [DateTime]$record.recordDate_hour_1
    $CsvData += [PSCustomObject]@{
        "Date" = $DateTime.ToString("yyyy-MM-dd")
        "Time" = $DateTime.ToString("HH:mm:ss")
        "DateTime" = $record.recordDate_hour_1
        "Hour" = $DateTime.Hour
        "DayOfWeek" = $DateTime.DayOfWeek
        "Entries" = $record.sumins
        "Exits" = $record.sumouts
        "NetFlow" = ($record.sumins - $record.sumouts)
        "TotalActivity" = ($record.sumins + $record.sumouts)
        "DataType" = $VeaData.parameters.data_type
        "DateGrouping" = $VeaData.parameters.date_grouping
    }
}

# Export to CSV
$CsvData | Export-Csv -Path $OutputFile -NoTypeInformation
Write-Host "CSV file created: $OutputFile" -ForegroundColor Green

# Show summary
Write-Host "`nConversion Summary:" -ForegroundColor Green
Write-Host "Input Records: $($VeaData.data.Count)" -ForegroundColor White
Write-Host "Output File: $OutputFile" -ForegroundColor White

# Show sample
Write-Host "`nFirst 5 rows of CSV:" -ForegroundColor Yellow
Get-Content $OutputFile | Select-Object -First 6 | ForEach-Object { Write-Host $_ }

Write-Host "`nFor Springshare LibInsights:" -ForegroundColor Cyan
Write-Host "1. Try importing this CSV file manually in LibInsights" -ForegroundColor White
Write-Host "2. Contact Springshare support about CSV import format requirements" -ForegroundColor White
Write-Host "3. Ask about API endpoints for automated imports" -ForegroundColor White