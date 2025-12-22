# VEA Occupancy to Gate Counts Converter
# Converts existing occupancy CSV files to simplified gate counts format
# Removes gate_end column, keeps only date and gate_start

param(
    [string]$OccupancyDirectory = "output\csv\occupancy",
    [string]$GateCountsDirectory = "output\csv\gate_counts"
)

Write-Host "VEA Occupancy to Gate Counts Converter" -ForegroundColor Green
Write-Host "Input directory: $OccupancyDirectory" -ForegroundColor Cyan
Write-Host "Output directory: $GateCountsDirectory" -ForegroundColor Cyan

# Ensure output directory exists
if (-not (Test-Path $GateCountsDirectory)) {
    New-Item -ItemType Directory -Path $GateCountsDirectory -Force | Out-Null
}

# Find all occupancy CSV files
$OccupancyFiles = Get-ChildItem -Path $OccupancyDirectory -Filter "*_springshare_import.csv" -ErrorAction SilentlyContinue

if (-not $OccupancyFiles -or $OccupancyFiles.Count -eq 0) {
    Write-Error "No occupancy CSV files found in $OccupancyDirectory"
    Write-Host "Make sure you've run the VEA-Zone-Extractor.ps1 script first."
    exit 1
}

Write-Host "Found $($OccupancyFiles.Count) occupancy files to convert" -ForegroundColor Yellow

$ConvertedFiles = @()

# Process each occupancy CSV file
foreach ($occupancyFile in $OccupancyFiles) {
    Write-Host ""
    Write-Host "Processing: $($occupancyFile.Name)" -ForegroundColor White
    
    try {
        # Read the CSV file
        $csvData = Import-Csv -Path $occupancyFile.FullName
        
        if (-not $csvData -or $csvData.Count -eq 0) {
            Write-Warning "No data found in $($occupancyFile.Name), skipping"
            continue
        }
        
        Write-Host "  Found $($csvData.Count) records" -ForegroundColor Gray
        
        # Create simplified data with only date and gate_start
        $simplifiedData = @()
        
        foreach ($record in $csvData) {
            # Create new record with only date and gate_start
            $newRecord = [PSCustomObject]@{
                date = $record.date
                gate_start = $record.gate_start
            }
            $simplifiedData += $newRecord
        }
        
        # Create output filename
        $outputFileName = $occupancyFile.Name -replace "_springshare_import.csv", "_gate_counts.csv"
        $outputPath = Join-Path $GateCountsDirectory $outputFileName
        
        # Export simplified CSV
        $simplifiedData | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
        
        Write-Host "  Created: $outputFileName" -ForegroundColor Green
        Write-Host "    Columns: date, gate_start" -ForegroundColor Gray
        Write-Host "    Records: $($simplifiedData.Count)" -ForegroundColor Gray
        
        $ConvertedFiles += $outputPath
        
    } catch {
        Write-Warning "Error processing $($occupancyFile.Name): $($_.Exception.Message)"
    }
}

if ($ConvertedFiles.Count -eq 0) {
    Write-Error "No files were successfully converted"
    exit 1
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "CONVERSION COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "Converted $($ConvertedFiles.Count) files successfully" -ForegroundColor White
Write-Host ""
Write-Host "Created Gate Count Files:" -ForegroundColor Cyan

foreach ($file in $ConvertedFiles) {
    $relativePath = $file -replace [regex]::Escape((Get-Location).Path), "."
    Write-Host "   $relativePath" -ForegroundColor White
}

Write-Host ""
Write-Host "Format: date, gate_start (gate_end column removed)" -ForegroundColor Gray
Write-Host "Ready for gate count analysis!" -ForegroundColor Green

# Show sample of first converted file
if ($ConvertedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Sample from first file:" -ForegroundColor Yellow
    
    try {
        $sampleData = Import-Csv -Path $ConvertedFiles[0] | Select-Object -First 5
        $sampleData | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } catch {
        Write-Host "  (Could not display sample data)" -ForegroundColor Gray
    }
}

Write-Host ""