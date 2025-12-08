param(
    [Parameter(Mandatory=$false)]
    [string]$StartDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd"),
    
    [Parameter(Mandatory=$false)]
    [string]$EndDate = (Get-Date).ToString("yyyy-MM-dd"),
    
    [Parameter(Mandatory=$false)]
    [string]$DataType = "traffic",
    
    [Parameter(Mandatory=$false)]
    [string]$DateGrouping = "hour",
    
    [Parameter(Mandatory=$false)]
    [string]$GateMethod = "Bidirectional"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Individual sensors from your list
$Sensors = @(
    @{ Id = "34e07466-3cd7-4e74-889a-b63891d056b5"; Name = "McKay Library Level 3 Stairs" },
    @{ Id = "5aeebd64-77eb-48c6-886b-9398703311d1"; Name = "McKay Library Level 2 Stairs" },
    @{ Id = "508b24fa-eebf-4fa7-9ccd-0130334a99fb"; Name = "McKay Library Level 3 Bridge" },
    @{ Id = "24a57257-03c4-4220-acf7-267bc8c9c344"; Name = "McKay Library Level 1 Main Entrance 1" },
    @{ Id = "e2d3ed7a-0838-4fbf-a0e1-9b60ceaa49b4"; Name = "McKay Library Level 1 New Entrance" }
)

Write-Host "=== VEA Individual Sensor Data Extractor ===" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan
Write-Host "Data Type: $DataType | Grouping: $DateGrouping" -ForegroundColor Cyan
Write-Host "Gate Method: $GateMethod" -ForegroundColor Cyan
Write-Host "Sensors to process: $($Sensors.Count)" -ForegroundColor Cyan

# Function to authenticate
function Get-VEAAccessToken {
    Write-Host "Authenticating with VEA..." -ForegroundColor Yellow
    
    $AuthBody = @{
        "grant_type" = "client_credentials"
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
    } | ConvertTo-Json

    $Headers = @{ "Content-Type" = "application/json" }

    try {
        $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers
        Write-Host "✓ Authentication successful" -ForegroundColor Green
        return $Response.access_token
    }
    catch {
        Write-Host "❌ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to get data for a specific sensor
function Get-IndividualSensorData {
    param(
        [string]$AccessToken,
        [hashtable]$Sensor,
        [string]$StartDate,
        [string]$EndDate,
        [string]$DataType,
        [string]$DateGrouping
    )

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    # Try different parameter combinations to get sensor-specific data
    $QueryAttempts = @(
        # Attempt 1: Use sensorId parameter
        @{
            "relativeDate" = "custom"
            "startDate" = $StartDate
            "endDate" = $EndDate
            "dateGroupings" = $DateGrouping
            "sensorId" = $Sensor.Id
        },
        # Attempt 2: Use sensor parameter
        @{
            "relativeDate" = "custom"
            "startDate" = $StartDate
            "endDate" = $EndDate
            "dateGroupings" = $DateGrouping
            "sensor" = $Sensor.Id
        },
        # Attempt 3: Use sensors array parameter
        @{
            "relativeDate" = "custom"
            "startDate" = $StartDate
            "endDate" = $EndDate
            "dateGroupings" = $DateGrouping
            "sensors" = $Sensor.Id
        }
    )

    foreach ($attempt in 0..($QueryAttempts.Count - 1)) {
        $QueryParams = $QueryAttempts[$attempt]
        $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
        $DataUrl = "$ApiBaseUrl/data/$DataType" + "?" + $QueryString

        Write-Host "  Attempt $($attempt + 1): Testing parameter combination..." -ForegroundColor Gray
        Write-Host "  URL: $DataUrl" -ForegroundColor DarkGray

        try {
            $Response = Invoke-RestMethod -Uri $DataUrl -Method Get -Headers $Headers
            
            if ($Response -and $Response.data -and $Response.data.results -and $Response.data.results.Count -gt 0) {
                Write-Host "  ✓ Success! Retrieved $($Response.data.results.Count) records" -ForegroundColor Green
                
                # Save individual sensor JSON file
                $SafeName = $Sensor.Name -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
                $JsonFileName = "${SafeName}_${StartDate}_to_${EndDate}.json"
                
                # Add sensor info to response for identification
                $Response | Add-Member -NotePropertyName "sensor_info" -NotePropertyValue @{
                    sensorId = $Sensor.Id
                    sensorName = $Sensor.Name
                    extractionTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    queryParameters = $QueryParams
                }
                
                $Response | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFileName -Encoding UTF8
                Write-Host "  📁 Saved: $JsonFileName" -ForegroundColor Cyan
                
                return $Response
            } else {
                Write-Host "  ⚠️ No data returned for this parameter combination" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ❌ Error with attempt $($attempt + 1): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "  ❌ All attempts failed for sensor: $($Sensor.Name)" -ForegroundColor Red
    return $null
}

# Function to create Springshare CSV from individual sensor data
function Create-SensorSpringshareCSV {
    param(
        [object]$SensorData,
        [hashtable]$Sensor,
        [string]$GateMethod
    )

    if (-not $SensorData -or -not $SensorData.data.results) {
        Write-Host "  ❌ No valid data to convert for $($Sensor.Name)" -ForegroundColor Red
        return
    }

    $SafeName = $Sensor.Name -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
    $OutputFile = "${SafeName}_springshare_import.csv"

    # Group by date and aggregate hourly data into daily totals
    $DailyTotals = @{}
    
    foreach ($record in $SensorData.data.results) {
        if ($record.recordDate_hour_1) {
            $DateTime = [DateTime]$record.recordDate_hour_1
            $DateKey = $DateTime.ToString("yyyy-MM-dd")
            
            if (-not $DailyTotals.ContainsKey($DateKey)) {
                $DailyTotals[$DateKey] = @{
                    "TotalEntries" = 0
                    "TotalExits" = 0
                }
            }
            
            $DailyTotals[$DateKey].TotalEntries += [int]$record.sumins
            $DailyTotals[$DateKey].TotalExits += [int]$record.sumouts
        }
    }

    if ($DailyTotals.Count -eq 0) {
        Write-Host "  ⚠️ No valid daily records found for $($Sensor.Name)" -ForegroundColor Yellow
        return
    }

    # Create Springshare format records
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

    # Create CSV content
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

    Write-Host "  ✅ Created CSV: $OutputFile" -ForegroundColor Green

    # Show summary
    if ($GateMethod.ToLower() -ne "manual") {
        $TotalEntries = ($SpringshareRecords | Measure-Object -Property gate_start -Sum).Sum
        $TotalExits = ($SpringshareRecords | Measure-Object -Property gate_end -Sum).Sum  
        Write-Host "     📊 $($SpringshareRecords.Count) days | Entries: $TotalEntries | Exits: $TotalExits" -ForegroundColor Gray
    } else {
        $TotalCount = ($SpringshareRecords | Measure-Object -Property gate_start -Sum).Sum
        Write-Host "     📊 $($SpringshareRecords.Count) days | Total Count: $TotalCount" -ForegroundColor Gray
    }

    return $OutputFile
}

# Main execution
Write-Host "`n🔑 Step 1: Authentication" -ForegroundColor Yellow
$AccessToken = Get-VEAAccessToken

if (-not $AccessToken) {
    Write-Host "❌ Cannot proceed without authentication. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "`n📡 Step 2: Extracting data for each sensor individually..." -ForegroundColor Yellow

$ProcessedSensors = @()
$SuccessfulExtractions = 0

foreach ($sensor in $Sensors) {
    Write-Host "`n🔍 Processing: $($sensor.Name)" -ForegroundColor Cyan
    Write-Host "   Sensor ID: $($sensor.Id)" -ForegroundColor DarkGray
    
    $SensorData = Get-IndividualSensorData -AccessToken $AccessToken -Sensor $sensor -StartDate $StartDate -EndDate $EndDate -DataType $DataType -DateGrouping $DateGrouping
    
    if ($SensorData) {
        $CsvFile = Create-SensorSpringshareCSV -SensorData $SensorData -Sensor $sensor -GateMethod $GateMethod
        
        if ($CsvFile) {
            $ProcessedSensors += @{
                Name = $sensor.Name
                Id = $sensor.Id
                JsonFile = "${sensor.Name -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'}_${StartDate}_to_${EndDate}.json"
                CsvFile = $CsvFile
                Success = $true
            }
            $SuccessfulExtractions++
        }
    } else {
        $ProcessedSensors += @{
            Name = $sensor.Name
            Id = $sensor.Id
            Success = $false
        }
        Write-Host "   ❌ Failed to extract data for this sensor" -ForegroundColor Red
    }
}

# Final Summary
Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "🎯 EXTRACTION COMPLETE" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

Write-Host "📅 Date Range: $StartDate to $EndDate" -ForegroundColor White
Write-Host "⚙️  Gate Method: $GateMethod" -ForegroundColor White
Write-Host "✅ Successful extractions: $SuccessfulExtractions / $($Sensors.Count)" -ForegroundColor White

Write-Host "`n📁 Generated Files:" -ForegroundColor Cyan
foreach ($processed in $ProcessedSensors | Where-Object { $_.Success }) {
    Write-Host "   • $($processed.CsvFile)" -ForegroundColor White
    Write-Host "   • $($processed.JsonFile)" -ForegroundColor Gray
}

if ($SuccessfulExtractions -eq 0) {
    Write-Host "`n⚠️  WARNING: No sensor data was successfully extracted!" -ForegroundColor Yellow
    Write-Host "This might indicate:" -ForegroundColor Yellow
    Write-Host "   • The VEA API doesn't support individual sensor queries for this data type" -ForegroundColor Yellow
    Write-Host "   • The sensor IDs are incorrect" -ForegroundColor Yellow
    Write-Host "   • The date range has no data" -ForegroundColor Yellow
    Write-Host "   • Different API parameters are needed" -ForegroundColor Yellow
} else {
    Write-Host "`n🎉 Ready for Springshare LibInsights import!" -ForegroundColor Green
}

Write-Host ""