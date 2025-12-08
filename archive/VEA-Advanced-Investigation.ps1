param(
    [string]$StartDate = "2025-12-01",
    [string]$EndDate = "2025-12-08",
    [string]$GateMethod = "Bidirectional"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Site-Sensor mapping based on your VEA reporting tool info
$SiteSensorMap = @(
    @{ SiteName = "Level 1 New Entrance"; SensorName = "McKay Library Level 1 New Entrance"; MacAddress = "00:6E:02:03:6E:44"; Active = $true },
    @{ SiteName = "Level 3 Bridge"; SensorName = "McKay Library Level 3 Bridge"; MacAddress = "00:6E:02:04:C9:A4"; Active = $true },
    @{ SiteName = "Level 2 Stairs"; SensorName = "McKay Library Level 2 Stairs"; MacAddress = "00:6E:02:03:6E:3C"; Active = $true },
    @{ SiteName = "Level 3 Stairs"; SensorName = "McKay Library Level 3 Stairs"; MacAddress = "00:6E:02:03:60:C0"; Active = $true },
    @{ SiteName = "Level 1 Main Entrance"; SensorName = "McKay Library Level 1 Main Entrance 1"; MacAddress = "00:6E:02:05:21:88"; Active = $true },
    @{ SiteName = "Level 2 Study Area"; SensorName = "Not active"; MacAddress = "00:6E:02:05:18:20"; Active = $false },
    @{ SiteName = "Level 1 Study Area"; SensorName = "Not active"; MacAddress = "00:6E:02:05:19:2C"; Active = $false }
)

Write-Host "=== VEA Site-Based Data Investigation ===" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan
Write-Host "Active sensors to process: $($SiteSensorMap | Where-Object { $_.Active } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor Cyan

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

# Test different API approaches to get site-specific data
function Test-SiteDataApproaches {
    param([string]$AccessToken)

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    Write-Host "`nTesting different API approaches..." -ForegroundColor Yellow

    # Approach 1: Try to get data broken down by site names
    $ActiveSites = $SiteSensorMap | Where-Object { $_.Active }
    
    foreach ($site in $ActiveSites) {
        Write-Host "`n--- Testing: $($site.SensorName) ---" -ForegroundColor Cyan
        Write-Host "Site: $($site.SiteName)" -ForegroundColor Gray
        Write-Host "MAC: $($site.MacAddress)" -ForegroundColor Gray

        # Test different parameter combinations
        $TestApproaches = @(
            @{ Name = "Site Name Filter"; Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&siteName=$($site.SiteName -replace ' ', '%20')" },
            @{ Name = "MAC Address Filter"; Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&macAddress=$($site.MacAddress)" },
            @{ Name = "Device Filter"; Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&device=$($site.MacAddress)" },
            @{ Name = "Sensor Name Filter"; Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&sensorName=$($site.SensorName -replace ' ', '%20')" }
        )

        foreach ($approach in $TestApproaches) {
            Write-Host "  Testing $($approach.Name)..." -ForegroundColor Yellow
            Write-Host "    URL: $($approach.Url)" -ForegroundColor DarkGray

            try {
                $Response = Invoke-RestMethod -Uri $approach.Url -Method Get -Headers $Headers
                
                if ($Response.data -and $Response.data.results -and $Response.data.results.Count -gt 0) {
                    Write-Host "    ✅ SUCCESS: $($Response.data.results.Count) records found!" -ForegroundColor Green
                    
                    # Save the successful response
                    $SafeName = $site.SensorName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
                    $FileName = "${SafeName}_individual_data.json"
                    $Response | ConvertTo-Json -Depth 10 | Out-File -FilePath $FileName -Encoding UTF8
                    Write-Host "    📁 Saved: $FileName" -ForegroundColor Cyan
                    
                    # Create CSV immediately
                    $CsvFile = Create-IndividualSensorCSV -SensorData $Response -SensorName $site.SensorName -GateMethod $GateMethod
                    
                    return $true  # Found working approach
                } else {
                    Write-Host "    ❌ No data returned" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    return $false
}

# Alternative: Try to get all data with detailed breakdown
function Test-DetailedDataStructure {
    param([string]$AccessToken)

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    Write-Host "`nTesting detailed data structures..." -ForegroundColor Yellow

    $DetailedApproaches = @(
        @{ Name = "All Sites with Details"; Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&includeDetails=true" },
        @{ Name = "All Sites with Site Breakdown"; Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&breakdown=site" },
        @{ Name = "All Sites with Sensor Breakdown"; Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&breakdown=sensor" },
        @{ Name = "Raw Traffic Data"; Url = "$ApiBaseUrl/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour" },
        @{ Name = "Sites Endpoint"; Url = "$ApiBaseUrl/sites/data?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour" }
    )

    foreach ($approach in $DetailedApproaches) {
        Write-Host "  Testing: $($approach.Name)" -ForegroundColor Yellow
        Write-Host "    URL: $($approach.Url)" -ForegroundColor DarkGray

        try {
            $Response = Invoke-RestMethod -Uri $approach.Url -Method Get -Headers $Headers
            
            Write-Host "    ✅ Success!" -ForegroundColor Green
            
            # Analyze structure
            if ($Response.data) {
                Write-Host "      Has data section" -ForegroundColor Cyan
                if ($Response.data.results) {
                    Write-Host "      Results: $($Response.data.results.Count) records" -ForegroundColor Cyan
                    
                    # Look at first record structure
                    if ($Response.data.results.Count -gt 0) {
                        $FirstRecord = $Response.data.results[0]
                        $Keys = $FirstRecord.PSObject.Properties.Name
                        Write-Host "      Record keys: $($Keys -join ', ')" -ForegroundColor Gray
                        
                        # Look for site/sensor identifiers
                        $SiteKeys = $Keys | Where-Object { $_ -match "site|sensor|mac|device|name" }
                        if ($SiteKeys) {
                            Write-Host "      🎯 Site/Sensor keys found: $($SiteKeys -join ', ')" -ForegroundColor Green
                        }
                    }
                }
            }
            
            # Save detailed response
            $FileName = "detailed_$($approach.Name -replace '[^a-zA-Z0-9]', '_').json"
            $Response | ConvertTo-Json -Depth 15 | Out-File -FilePath $FileName -Encoding UTF8
            Write-Host "      📁 Saved: $FileName" -ForegroundColor Cyan
            
        }
        catch {
            Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Create individual sensor CSV
function Create-IndividualSensorCSV {
    param(
        [object]$SensorData,
        [string]$SensorName,
        [string]$GateMethod
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

    if ($DailyTotals.Count -eq 0) {
        Write-Host "    ❌ No valid data for CSV creation" -ForegroundColor Red
        return $null
    }

    # Create Springshare CSV
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

    Write-Host "    ✅ Created: $CsvFile" -ForegroundColor Green
    
    # Show summary
    $TotalEntries = ($DailyTotals.Values | Measure-Object -Property Entries -Sum).Sum
    $TotalExits = ($DailyTotals.Values | Measure-Object -Property Exits -Sum).Sum
    Write-Host "       📊 Days: $($DailyTotals.Count) | Entries: $TotalEntries | Exits: $TotalExits" -ForegroundColor Gray
    
    return $CsvFile
}

# Main execution
Write-Host "`n🔑 Authenticating..." -ForegroundColor Yellow
$AccessToken = Get-VEAAccessToken

if (-not $AccessToken) {
    Write-Host "❌ Authentication failed. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Authentication successful" -ForegroundColor Green

# Try to find working approach for individual sensor data
$FoundWorkingApproach = Test-SiteDataApproaches -AccessToken $AccessToken

if (-not $FoundWorkingApproach) {
    Write-Host "`n⚠️ No individual sensor data found. Testing detailed structures..." -ForegroundColor Yellow
    Test-DetailedDataStructure -AccessToken $AccessToken
}

Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "🔍 INVESTIGATION COMPLETE" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

if ($FoundWorkingApproach) {
    Write-Host "✅ Successfully extracted individual sensor data!" -ForegroundColor Green
    Write-Host "📁 Check the created CSV and JSON files." -ForegroundColor Cyan
} else {
    Write-Host "⚠️ Could not extract individual sensor data via API." -ForegroundColor Yellow
    Write-Host "📁 Check the detailed JSON files for structure analysis." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "1. Review the generated JSON files for hidden sensor identifiers" -ForegroundColor Gray
    Write-Host "2. Consider that the VEA web UI might aggregate data client-side" -ForegroundColor Gray
    Write-Host "3. We may need to split the aggregated data proportionally" -ForegroundColor Gray
}

Write-Host ""