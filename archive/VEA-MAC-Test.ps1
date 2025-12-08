param(
    [string]$StartDate = "2025-12-01",
    [string]$EndDate = "2025-12-08"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com/api"

# Active sensors based on your VEA reporting info
$ActiveSensors = @(
    @{ Name = "McKay Library Level 1 New Entrance"; MacAddress = "00:6E:02:03:6E:44" },
    @{ Name = "McKay Library Level 3 Bridge"; MacAddress = "00:6E:02:04:C9:A4" },
    @{ Name = "McKay Library Level 2 Stairs"; MacAddress = "00:6E:02:03:6E:3C" },
    @{ Name = "McKay Library Level 3 Stairs"; MacAddress = "00:6E:02:03:60:C0" },
    @{ Name = "McKay Library Level 1 Main Entrance 1"; MacAddress = "00:6E:02:05:21:88" }
)

Write-Host "Testing MAC Address Filtering" -ForegroundColor Green
Write-Host "Sensors to test: $($ActiveSensors.Count)" -ForegroundColor Cyan

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

# Test MAC address filtering
function Test-MacAddressFiltering {
    param([string]$AccessToken)

    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    foreach ($sensor in $ActiveSensors) {
        Write-Host ""
        Write-Host "Testing: $($sensor.Name)" -ForegroundColor Yellow
        Write-Host "MAC: $($sensor.MacAddress)" -ForegroundColor Gray

        # Build URL manually to avoid ampersand issues
        $BaseUrl = "$ApiBaseUrl/data/traffic"
        $Params = @(
            "relativeDate=custom",
            "startDate=$StartDate",
            "endDate=$EndDate", 
            "dateGroupings=hour",
            "macAddress=$($sensor.MacAddress)"
        )
        
        $TestUrl = $BaseUrl + "?" + ($Params -join "&")
        Write-Host "URL: $TestUrl" -ForegroundColor DarkGray

        try {
            $Response = Invoke-RestMethod -Uri $TestUrl -Method Get -Headers $Headers
            
            if ($Response.data.results -and $Response.data.results.Count -gt 0) {
                Write-Host "SUCCESS: Found $($Response.data.results.Count) records!" -ForegroundColor Green
                
                # Save data
                $SafeName = $sensor.Name -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '_'
                $JsonFile = "${SafeName}_mac_data.json"
                $Response | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFile -Encoding UTF8
                Write-Host "Saved: $JsonFile" -ForegroundColor Cyan
                
                return $true
            } else {
                Write-Host "No data returned" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    return $false
}

# Main execution
Write-Host ""
$AccessToken = Get-VEAAccessToken

if ($AccessToken) {
    Write-Host "Authentication successful" -ForegroundColor Green
    $Success = Test-MacAddressFiltering -AccessToken $AccessToken
    
    if (-not $Success) {
        Write-Host ""
        Write-Host "MAC address filtering didn't work. The API might not support individual sensor queries." -ForegroundColor Yellow
    }
} else {
    Write-Host "Authentication failed" -ForegroundColor Red
}

Write-Host ""