# VEA API Input Validation Module
# Provides comprehensive validation for API inputs and parameters

class VeaValidator {
    # Validate VEA API credentials format and accessibility
    static [bool] TestApiCredentials([string]$clientId, [string]$clientSecret) {
        # Basic format validation (UUID for client ID, reasonable length for secret)
        $uuidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        $isValidClientId = $clientId -match $uuidPattern
        $isValidClientSecret = -not [string]::IsNullOrEmpty($clientSecret) -and $clientSecret.Length -gt 20

        if (-not ($isValidClientId -and $isValidClientSecret)) {
            Write-Host "Invalid credential format" -ForegroundColor Red
            return $false
        }

        # Test actual API connectivity
        return [VeaValidator]::TestApiConnectivity($clientId, $clientSecret)
    }

    # Test if credentials can actually authenticate with VEA API
    static [bool] TestApiConnectivity([string]$clientId, [string]$clientSecret) {
        $authUrl = "https://auth.sensourceinc.com/oauth/token"
        $apiBaseUrl = "https://vea.sensourceinc.com/api"

        try {
            # Attempt to get access token
            $authBody = @{
                grant_type = "client_credentials"
                client_id = $clientId
                client_secret = $clientSecret
            } | ConvertTo-Json

            $headers = @{ "Content-Type" = "application/json" }

            $tokenResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Body $authBody -Headers $headers -TimeoutSec 10

            if (-not $tokenResponse.access_token) {
                return $false
            }

            # Test a simple API call to ensure token works
            $apiHeaders = @{
                "Authorization" = "Bearer $($tokenResponse.access_token)"
                "Content-Type" = "application/json"
            }

            $zonesResponse = Invoke-RestMethod -Uri "$apiBaseUrl/zone" -Method Get -Headers $apiHeaders -TimeoutSec 10

            return $true
        }
        catch {
            Write-Host "API connectivity test failed: $($_.Exception.Message)" -ForegroundColor Yellow
            return $false
        }
    }

    # Validate date format and logical consistency
    static [bool] TestDateRange([string]$startDate, [string]$endDate) {
        try {
            # Parse dates
            $start = [DateTime]::Parse($startDate)
            $end = [DateTime]::Parse($endDate)

            # Check logical consistency
            if ($start -gt $end) {
                Write-Host "Start date cannot be after end date" -ForegroundColor Red
                return $false
            }

            # Check reasonable date range (not too far in past/future)
            $now = [DateTime]::Now
            $maxPastDays = 365 * 2  # 2 years
            $maxFutureDays = 30     # 30 days

            if (($now - $start).TotalDays -gt $maxPastDays) {
                Write-Host "Start date is too far in the past (max: $maxPastDays days)" -ForegroundColor Red
                return $false
            }

            if (($end - $now).TotalDays -gt $maxFutureDays) {
                Write-Host "End date is too far in the future (max: $maxFutureDays days)" -ForegroundColor Red
                return $false
            }

            return $true
        }
        catch {
            Write-Host "Invalid date format: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    # Validate gate method parameter
    static [bool] TestGateMethod([string]$gateMethod) {
        $validMethods = @("Bidirectional", "Unidirectional", "Manual")

        if ($gateMethod -notin $validMethods) {
            Write-Host "Invalid gate method: $gateMethod. Valid options: $($validMethods -join ', ')" -ForegroundColor Red
            return $false
        }

        return $true
    }

    # Validate data type parameter
    static [bool] TestDataType([string]$dataType) {
        $validTypes = @("traffic", "occupancy", "pos")

        if ($dataType -notin $validTypes) {
            Write-Host "Invalid data type: $dataType. Valid options: $($validTypes -join ', ')" -ForegroundColor Red
            return $false
        }

        return $true
    }

    # Validate date grouping parameter
    static [bool] TestDateGrouping([string]$dateGrouping) {
        $validGroupings = @("hour", "day", "month", "minute(15)", "minute(30)", "minute(60)")

        if ($dateGrouping -notin $validGroupings) {
            Write-Host "Invalid date grouping: $dateGrouping. Valid options: $($validGroupings -join ', ')" -ForegroundColor Red
            return $false
        }

        return $true
    }

    # Validate file paths and permissions
    static [bool] TestFilePermissions([string]$path, [string]$operation) {
        switch ($operation) {
            "read" {
                if (-not (Test-Path $path)) {
                    Write-Host "File does not exist: $path" -ForegroundColor Red
                    return $false
                }

                try {
                    $content = Get-Content $path -TotalCount 1 -ErrorAction Stop
                    return $true
                }
                catch {
                    Write-Host "Cannot read file: $path - $($_.Exception.Message)" -ForegroundColor Red
                    return $false
                }
            }
            "write" {
                $directory = Split-Path $path -Parent

                if (-not (Test-Path $directory)) {
                    try {
                        New-Item -ItemType Directory -Path $directory -Force | Out-Null
                    }
                    catch {
                        Write-Host "Cannot create directory: $directory - $($_.Exception.Message)" -ForegroundColor Red
                        return $false
                    }
                }

                try {
                    # Test write permission by creating a temporary file
                    $testFile = Join-Path $directory "test_write.tmp"
                    "test" | Out-File $testFile -Force
                    Remove-Item $testFile -Force
                    return $true
                }
                catch {
                    Write-Host "Cannot write to directory: $directory - $($_.Exception.Message)" -ForegroundColor Red
                    return $false
                }
            }
            default {
                Write-Host "Invalid operation: $operation. Use 'read' or 'write'" -ForegroundColor Red
                return $false
            }
        }

        # This should never be reached, but ensures all code paths return a value
        return $false
    }

    # Comprehensive parameter validation for main scripts
    static [bool] TestScriptParameters([hashtable]$parameters) {
        $isValid = $true

        # Required parameters
        if (-not $parameters.ContainsKey('StartDate') -or [string]::IsNullOrEmpty($parameters.StartDate)) {
            Write-Host "StartDate parameter is required" -ForegroundColor Red
            $isValid = $false
        }

        if (-not $parameters.ContainsKey('EndDate') -or [string]::IsNullOrEmpty($parameters.EndDate)) {
            Write-Host "EndDate parameter is required" -ForegroundColor Red
            $isValid = $false
        }

        # Validate date range if both dates provided
        if ($parameters.StartDate -and $parameters.EndDate) {
            if (-not [VeaValidator]::TestDateRange($parameters.StartDate, $parameters.EndDate)) {
                $isValid = $false
            }
        }

        # Validate optional parameters
        if ($parameters.ContainsKey('GateMethod') -and $parameters.GateMethod) {
            if (-not [VeaValidator]::TestGateMethod($parameters.GateMethod)) {
                $isValid = $false
            }
        }

        if ($parameters.ContainsKey('DataType') -and $parameters.DataType) {
            if (-not [VeaValidator]::TestDataType($parameters.DataType)) {
                $isValid = $false
            }
        }

        if ($parameters.ContainsKey('DateGrouping') -and $parameters.DateGrouping) {
            if (-not [VeaValidator]::TestDateGrouping($parameters.DateGrouping)) {
                $isValid = $false
            }
        }

        return $isValid
    }
}

# Convenience functions for common validation tasks
function Test-VeaApiCredentials {
    param([string]$ClientId, [string]$ClientSecret)
    return [VeaValidator]::TestApiCredentials($ClientId, $ClientSecret)
}

function Test-VeaDateRange {
    param([string]$StartDate, [string]$EndDate)
    return [VeaValidator]::TestDateRange($StartDate, $EndDate)
}

function Test-VeaFilePermissions {
    param([string]$Path, [string]$Operation)
    return [VeaValidator]::TestFilePermissions($Path, $Operation)
}