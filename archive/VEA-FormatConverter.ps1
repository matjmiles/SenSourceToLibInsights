# VEA to Common Library Statistics Format Converter
# Converts VEA JSON data to common formats used by library systems

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFormat = "CSV",  # CSV, JSON, XML, COUNTER
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = ""
)

Write-Host "=== VEA Data Format Converter ===" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Cyan
Write-Host "Output Format: $OutputFormat" -ForegroundColor Cyan

# Check if input file exists
if (-not (Test-Path $InputFile)) {
    Write-Host "❌ Input file not found: $InputFile" -ForegroundColor Red
    exit 1
}

# Load VEA data
try {
    $VeaData = Get-Content $InputFile | ConvertFrom-Json
    Write-Host "✓ Loaded VEA data successfully" -ForegroundColor Green
    Write-Host "  Extraction Date: $($VeaData.extraction_timestamp)" -ForegroundColor White
    Write-Host "  Data Type: $($VeaData.parameters.data_type)" -ForegroundColor White
    Write-Host "  Records: $($VeaData.data.Count)" -ForegroundColor White
}
catch {
    Write-Host "❌ Failed to load VEA data: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Generate output filename if not provided
if ($OutputFile -eq "") {
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $OutputFile = "${BaseName}_converted.$($OutputFormat.ToLower())"
}

Write-Host "`nConverting to $OutputFormat format..." -ForegroundColor Yellow

# Convert based on format
switch ($OutputFormat.ToUpper()) {
    "CSV" {
        Write-Host "Creating CSV format suitable for library systems..." -ForegroundColor Gray
        
        # Create CSV with standard library statistics columns
        $CsvData = @()
        foreach ($record in $VeaData.data) {
            $CsvData += [PSCustomObject]@{
                "Date" = $record.recordDate_hour_1
                "Hour" = ([DateTime]$record.recordDate_hour_1).Hour
                "DayOfWeek" = ([DateTime]$record.recordDate_hour_1).DayOfWeek
                "Entries" = $record.sumins
                "Exits" = $record.sumouts
                "NetFlow" = ($record.sumins - $record.sumouts)
                "TotalActivity" = ($record.sumins + $record.sumouts)
                "DataType" = $VeaData.parameters.data_type
                "DateGrouping" = $VeaData.parameters.date_grouping
            }
        }
        
        $CsvData | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "✓ CSV file created: $OutputFile" -ForegroundColor Green
    }
    
    "JSON" {
        Write-Host "Creating JSON format suitable for API import..." -ForegroundColor Gray
        
        # Create simplified JSON structure
        $JsonOutput = @{
            "metadata" = @{
                "source" = "VEA API"
                "extraction_date" = $VeaData.extraction_timestamp
                "date_range" = @{
                    "start" = $VeaData.parameters.start_date
                    "end" = $VeaData.parameters.end_date
                }
                "data_type" = $VeaData.parameters.data_type
                "grouping" = $VeaData.parameters.date_grouping
            }
            "statistics" = @()
        }
        
        foreach ($record in $VeaData.data) {
            $JsonOutput.statistics += @{
                "timestamp" = $record.recordDate_hour_1
                "metrics" = @{
                    "entries" = $record.sumins
                    "exits" = $record.sumouts
                    "net_flow" = ($record.sumins - $record.sumouts)
                    "total_activity" = ($record.sumins + $record.sumouts)
                }
            }
        }
        
        $JsonOutput | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "✓ JSON file created: $OutputFile" -ForegroundColor Green
    }
    
    "XML" {
        Write-Host "Creating XML format..." -ForegroundColor Gray
        
        $XmlOutput = @"
<?xml version="1.0" encoding="UTF-8"?>
<libraryStatistics>
    <metadata>
        <source>VEA API</source>
        <extractionDate>$($VeaData.extraction_timestamp)</extractionDate>
        <dateRange>
            <start>$($VeaData.parameters.start_date)</start>
            <end>$($VeaData.parameters.end_date)</end>
        </dateRange>
        <dataType>$($VeaData.parameters.data_type)</dataType>
        <grouping>$($VeaData.parameters.date_grouping)</grouping>
    </metadata>
    <records>
"@
        
        foreach ($record in $VeaData.data) {
            $XmlOutput += @"
        <record>
            <timestamp>$($record.recordDate_hour_1)</timestamp>
            <entries>$($record.sumins)</entries>
            <exits>$($record.sumouts)</exits>
            <netFlow>$($record.sumins - $record.sumouts)</netFlow>
            <totalActivity>$($record.sumins + $record.sumouts)</totalActivity>
        </record>
"@
        }
        
        $XmlOutput += @"
    </records>
</libraryStatistics>
"@
        
        $XmlOutput | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "✓ XML file created: $OutputFile" -ForegroundColor Green
    }
    
    "COUNTER" {
        Write-Host "Creating COUNTER-like format for library usage statistics..." -ForegroundColor Gray
        
        # Create COUNTER-inspired format (simplified)
        $CounterData = @()
        foreach ($record in $VeaData.data) {
            $CounterData += [PSCustomObject]@{
                "Report_ID" = "VEA_TR"  # Traffic Report
                "Report_Name" = "VEA Traffic Report"
                "Institution_Name" = "Library"
                "Period" = ([DateTime]$record.recordDate_hour_1).ToString("yyyy-MM")
                "Usage_Date" = $record.recordDate_hour_1
                "Metric_Type" = "Total_Visits"
                "Count" = ($record.sumins + $record.sumouts)
                "Entries" = $record.sumins
                "Exits" = $record.sumouts
            }
        }
        
        $CounterData | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "✓ COUNTER-like CSV file created: $OutputFile" -ForegroundColor Green
    }
    
    default {
        Write-Host "❌ Unsupported format: $OutputFormat" -ForegroundColor Red
        Write-Host "Supported formats: CSV, JSON, XML, COUNTER" -ForegroundColor Yellow
        exit 1
    }
}

# Show summary
Write-Host "`n=== Conversion Summary ===" -ForegroundColor Green
Write-Host "Input Records: $($VeaData.data.Count)" -ForegroundColor White
Write-Host "Output File: $OutputFile" -ForegroundColor White
Write-Host "Format: $OutputFormat" -ForegroundColor White

# Show sample of converted data
Write-Host "`nSample of converted data:" -ForegroundColor Yellow
if ($OutputFormat.ToUpper() -eq "CSV" -or $OutputFormat.ToUpper() -eq "COUNTER") {
    Get-Content $OutputFile | Select-Object -First 5 | Write-Host
} else {
    Get-Content $OutputFile | Select-Object -First 10 | Write-Host
}

Write-Host "`n=== Conversion Complete ===" -ForegroundColor Green
Write-Host "`nNext Steps for Springshare Import:" -ForegroundColor Cyan
Write-Host "1. Test the CSV format with Springshare LibInsights manual import" -ForegroundColor White
Write-Host "2. Contact Springshare support about supported import formats" -ForegroundColor White
Write-Host "3. If API import is available, try the JSON format" -ForegroundColor White