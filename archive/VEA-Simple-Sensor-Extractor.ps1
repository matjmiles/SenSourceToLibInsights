param(
    [string]$StartDate = "2025-12-01",
    [string]$EndDate = "2025-12-08",
    [string]$DataType = "traffic",
    [string]$DateGrouping = "hour",
    [string]$GateMethod = "Bidirectional"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Individual sensors
$Sensors = @(
    @{ Id = "34e07466-3cd7-4e74-889a-b63891d056b5"; Name = "McKay Library Level 3 Stairs" },
    @{ Id = "5aeebd64-77eb-48c6-886b-9398703311d1"; Name = "McKay Library Level 2 Stairs" },
    @{ Id = "508b24fa-eebf-4fa7-9ccd-0130334a99fb"; Name = "McKay Library Level 3 Bridge" },
    @{ Id = "24a57257-03c4-4220-acf7-267bc8c9c344"; Name = "McKay Library Level 1 Main Entrance 1" },
    @{ Id = "e2d3ed7a-0838-4fbf-a0e1-9b60ceaa49b4"; Name = "McKay Library Level 1 New Entrance" }
)

Write-Host "VEA Individual Sensor Data Extractor" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan
Write-Host "Sensors: $($Sensors.Count)" -ForegroundColor Cyan

# Authentication
function Get-VEAAccessToken {
    $AuthBody = @{
        "grant_type" = "client_credentials"
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
    } | ConvertTo-Json

    $Headers = @{ "Content-Type" = "application/json" }

    try {
        $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers
        return $Response.access_token
    }
    catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Get sensor data
function Get-SensorData {
    param(
        [string]$AccessToken,
        [string]$SensorId,
        [string]$SensorName
    )

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    # Build URL with sensor filter
    $BaseUrl = "$ApiBaseUrl/data/$DataType"
    $Params = @(
        "relativeDate=custom",
        "startDate=$StartDate", 
        "endDate=$EndDate",
        "dateGroupings=$DateGrouping",
        "sensorId=$SensorId"
    )
    
    $DataUrl = $BaseUrl + "?" + ($Params -join "&")
    
    Write-Host "  Querying: $SensorName" -ForegroundColor Yellow
    Write-Host "  URL: $DataUrl" -ForegroundColor Gray

    try {
        $Response = Invoke-RestMethod -Uri $DataUrl -Method Get -Headers $Headers
        
        if ($Response.data.results -and $Response.data.results.Count -gt 0) {
            Write-Host "  Success: $($Response.data.results.Count) records" -ForegroundColor Green
            return $Response
        } else {
            Write-Host "  No data returned" -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Create CSV file
function Create-SensorCSV {
    param(
        [object]$SensorData,
        [string]$SensorName
    )

    $SafeName = $SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
    $CsvFile = "${SafeName}_springshare_import.csv"

    # Group by date
    $DailyTotals = @{}
    
    foreach ($record in $SensorData.data.results) {
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

    # Create CSV
    $CsvLines = @("date,gate_start,gate_end")

    foreach ($date in $DailyTotals.Keys | Sort-Object) {
        $totals = $DailyTotals[$date]
        
        if ($GateMethod -eq "manual") {
            $total = $totals.Entries + $totals.Exits
            $CsvLines += "$date,$total,"
        } else {
            $CsvLines += "$date,$($totals.Entries),$($totals.Exits)"
        }
    }

    # Save file
    $CsvContent = $CsvLines -join "`n"
    [System.IO.File]::WriteAllText($CsvFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "  Created: $CsvFile" -ForegroundColor Green
    return $CsvFile
}

# Main execution
Write-Host ""
Write-Host "Authenticating..." -ForegroundColor Yellow
$AccessToken = Get-VEAAccessToken

if (-not $AccessToken) {
    Write-Host "Authentication failed. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Authentication successful" -ForegroundColor Green
Write-Host ""

$CreatedFiles = @()

foreach ($sensor in $Sensors) {
    Write-Host "Processing: $($sensor.Name)" -ForegroundColor Cyan
    
    $SensorData = Get-SensorData -AccessToken $AccessToken -SensorId $sensor.Id -SensorName $sensor.Name
    
    if ($SensorData) {
        $CsvFile = Create-SensorCSV -SensorData $SensorData -SensorName $sensor.Name
        $CreatedFiles += $CsvFile
        
        # Save JSON too
        $SafeName = $sensor.Name -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
        $JsonFile = "${SafeName}_data.json"
        $SensorData | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFile -Encoding UTF8
        Write-Host "  Saved: $JsonFile" -ForegroundColor Gray
    }
    
    Write-Host ""
}

Write-Host "Processing Complete" -ForegroundColor Green
Write-Host "Created CSV files:" -ForegroundColor Cyan

foreach ($file in $CreatedFiles) {
    Write-Host "  $file" -ForegroundColor White
}

Write-Host ""
Write-Host "Ready for Springshare import!" -ForegroundColor Green