param(
    [string]$StartDate = "2025-12-01",
    [string]$EndDate = "2025-12-08"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

Write-Host "VEA API Data Structure Investigation" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan

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

# Test different API endpoint variations
function Test-APIEndpoints {
    param([string]$AccessToken)

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    $TestEndpoints = @(
        # Test 1: Default traffic data (what we had before)
        @{
            Name = "Default Traffic Data"
            Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour"
        },
        # Test 2: Try with different groupings
        @{
            Name = "Traffic Data with Site Grouping"
            Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&groupBy=site"
        },
        # Test 3: Try with sensor grouping
        @{
            Name = "Traffic Data with Sensor Grouping"
            Url = "$ApiBaseUrl/data/traffic?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour&groupBy=sensor"
        },
        # Test 4: Try raw sensor data endpoint
        @{
            Name = "Raw Sensor Data"
            Url = "$ApiBaseUrl/sensors/data?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour"
        },
        # Test 5: Try detailed traffic
        @{
            Name = "Detailed Traffic"
            Url = "$ApiBaseUrl/data/traffic/detailed?relativeDate=custom&startDate=$StartDate&endDate=$EndDate&dateGroupings=hour"
        }
    )

    foreach ($test in $TestEndpoints) {
        Write-Host ""
        Write-Host "Testing: $($test.Name)" -ForegroundColor Yellow
        Write-Host "URL: $($test.Url)" -ForegroundColor Gray

        try {
            $Response = Invoke-RestMethod -Uri $test.Url -Method Get -Headers $Headers
            
            Write-Host "Success!" -ForegroundColor Green
            
            # Analyze response structure
            if ($Response.data) {
                Write-Host "  Data section found" -ForegroundColor Cyan
                if ($Response.data.results) {
                    Write-Host "  Results: $($Response.data.results.Count) records" -ForegroundColor Cyan
                    
                    # Check first record structure
                    if ($Response.data.results.Count -gt 0) {
                        $FirstRecord = $Response.data.results[0]
                        Write-Host "  First record keys: $($FirstRecord.PSObject.Properties.Name -join ', ')" -ForegroundColor Gray
                        
                        # Look for sensor-related fields
                        $SensorFields = $FirstRecord.PSObject.Properties.Name | Where-Object { $_ -match "sensor|site|id" }
                        if ($SensorFields) {
                            Write-Host "  Sensor-related fields found: $($SensorFields -join ', ')" -ForegroundColor Green
                        }
                    }
                }
            }
            
            # Check for sites section
            if ($Response.sites) {
                Write-Host "  Sites section: $($Response.sites.value.Count) sites" -ForegroundColor Cyan
            }
            
            # Save detailed response
            $FileName = "api_test_$($test.Name -replace '[^a-zA-Z0-9]', '_').json"
            $Response | ConvertTo-Json -Depth 15 | Out-File -FilePath $FileName -Encoding UTF8
            Write-Host "  Saved: $FileName" -ForegroundColor Gray
            
        }
        catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
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

Test-APIEndpoints -AccessToken $AccessToken

Write-Host ""
Write-Host "Investigation complete. Check the generated JSON files for detailed response structures." -ForegroundColor Green