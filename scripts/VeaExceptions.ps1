# VEA API Custom Exception Classes
# Provides structured error handling throughout the application

class VeaException : Exception {
    [string]$ErrorCode
    [hashtable]$Context

    VeaException([string]$message) : base($message) {
        $this.ErrorCode = "VEA_GENERAL_ERROR"
        $this.Context = @{}
    }

    VeaException([string]$message, [string]$errorCode) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = @{}
    }

    VeaException([string]$message, [string]$errorCode, [hashtable]$context) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = $context
    }

    [string] ToString() {
        $contextStr = if ($this.Context.Count -gt 0) {
            " Context: $($this.Context | ConvertTo-Json -Compress)"
        } else { "" }

        return "[$($this.ErrorCode)] $($this.Message)$contextStr"
    }
}

class VeaApiException : VeaException {
    VeaApiException([string]$message) : base($message, "VEA_API_ERROR") {}

    VeaApiException([string]$message, [hashtable]$context) : base($message, "VEA_API_ERROR", $context) {}
}

class VeaAuthenticationException : VeaApiException {
    VeaAuthenticationException([string]$message) : base($message, "VEA_AUTH_ERROR") {}

    VeaAuthenticationException([string]$message, [hashtable]$context) : base($message, "VEA_AUTH_ERROR", $context) {}
}

class VeaConfigurationException : VeaException {
    VeaConfigurationException([string]$message) : base($message, "VEA_CONFIG_ERROR") {}

    VeaConfigurationException([string]$message, [hashtable]$context) : base($message, "VEA_CONFIG_ERROR", $context) {}
}

class VeaValidationException : VeaException {
    VeaValidationException([string]$message) : base($message, "VEA_VALIDATION_ERROR") {}

    VeaValidationException([string]$message, [hashtable]$context) : base($message, "VEA_VALIDATION_ERROR", $context) {}
}

class VeaDataException : VeaException {
    VeaDataException([string]$message) : base($message, "VEA_DATA_ERROR") {}

    VeaDataException([string]$message, [hashtable]$context) : base($message, "VEA_DATA_ERROR", $context) {}
}

# Error handling utilities
class VeaErrorHandler {
    static [void] HandleException([Exception]$exception) {
        switch ($exception.GetType().Name) {
            "VeaAuthenticationException" {
                [VeaErrorHandler]::HandleAuthenticationError($exception)
            }
            "VeaApiException" {
                [VeaErrorHandler]::HandleApiError($exception)
            }
            "VeaConfigurationException" {
                [VeaErrorHandler]::HandleConfigurationError($exception)
            }
            "VeaValidationException" {
                [VeaErrorHandler]::HandleValidationError($exception)
            }
            "VeaDataException" {
                [VeaErrorHandler]::HandleDataError($exception)
            }
            default {
                [VeaErrorHandler]::HandleGeneralError($exception)
            }
        }
    }

    static [void] HandleAuthenticationError([VeaAuthenticationException]$exception) {
        Write-Host "Authentication Error:" -ForegroundColor Red
        Write-Host "  $($exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check:" -ForegroundColor Yellow
        Write-Host "  - Client ID and Client Secret are correct" -ForegroundColor Yellow
        Write-Host "  - Your VEA API account is active" -ForegroundColor Yellow
        Write-Host "  - Network connectivity to VEA servers" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To reconfigure credentials: .\scripts\setup-credentials.ps1" -ForegroundColor Cyan
    }

    static [void] HandleApiError([VeaApiException]$exception) {
        Write-Host "API Error:" -ForegroundColor Red
        Write-Host "  $($exception.Message)" -ForegroundColor Red

        if ($exception.Context.ContainsKey('StatusCode')) {
            Write-Host "  HTTP Status: $($exception.Context.StatusCode)" -ForegroundColor Red
        }

        if ($exception.Context.ContainsKey('Endpoint')) {
            Write-Host "  Endpoint: $($exception.Context.Endpoint)" -ForegroundColor Red
        }
    }

    static [void] HandleConfigurationError([VeaConfigurationException]$exception) {
        Write-Host "Configuration Error:" -ForegroundColor Red
        Write-Host "  $($exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please run: .\scripts\setup-credentials.ps1" -ForegroundColor Cyan
    }

    static [void] HandleValidationError([VeaValidationException]$exception) {
        Write-Host "Validation Error:" -ForegroundColor Red
        Write-Host "  $($exception.Message)" -ForegroundColor Red

        if ($exception.Context.ContainsKey('Parameter')) {
            Write-Host "  Parameter: $($exception.Context.Parameter)" -ForegroundColor Red
        }

        if ($exception.Context.ContainsKey('Value')) {
            Write-Host "  Value: $($exception.Context.Value)" -ForegroundColor Red
        }
    }

    static [void] HandleDataError([VeaDataException]$exception) {
        Write-Host "Data Processing Error:" -ForegroundColor Red
        Write-Host "  $($exception.Message)" -ForegroundColor Red

        if ($exception.Context.ContainsKey('File')) {
            Write-Host "  File: $($exception.Context.File)" -ForegroundColor Red
        }

        if ($exception.Context.ContainsKey('RecordCount')) {
            Write-Host "  Records processed: $($exception.Context.RecordCount)" -ForegroundColor Red
        }
    }

    static [void] HandleGeneralError([Exception]$exception) {
        Write-Host "Unexpected Error:" -ForegroundColor Red
        Write-Host "  $($exception.Message)" -ForegroundColor Red
        Write-Host "  Type: $($exception.GetType().Name)" -ForegroundColor Red

        if ($global:PSVersionTable.PSVersion.Major -lt 7) {
            Write-Host "  Stack Trace: $($exception.StackTrace)" -ForegroundColor Gray
        }
    }

    # Safe execution wrapper
    static [object] SafeExecute([scriptblock]$action, [string]$operationName = "operation") {
        try {
            return & $action
        }
        catch [VeaException] {
            Write-Host "VEA $operationName failed:" -ForegroundColor Red
            [VeaErrorHandler]::HandleException($_)
            throw
        }
        catch {
            Write-Host "Unexpected error during $operationName :" -ForegroundColor Red
            [VeaErrorHandler]::HandleException($_)
            throw
        }
    }

    # Retry wrapper for transient failures
    static [object] RetryExecute([scriptblock]$action, [int]$maxRetries = 3, [int]$delaySeconds = 2) {
        $attempt = 0

        while ($attempt -lt $maxRetries) {
            $attempt++

            try {
                return & $action
            }
            catch {
                if ($attempt -eq $maxRetries) {
                    throw
                }

                Write-Host "Attempt $attempt failed, retrying in $delaySeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $delaySeconds
                $delaySeconds *= 2  # Exponential backoff
            }
        }

        # This should never be reached, but ensures all code paths return a value
        throw "Retry logic failed unexpectedly"
    }
}

# Convenience functions for error handling
function Invoke-VeaSafe {
    param([scriptblock]$ScriptBlock, [string]$OperationName = "operation")
    return [VeaErrorHandler]::SafeExecute($ScriptBlock, $OperationName)
}

function Invoke-VeaRetry {
    param([scriptblock]$ScriptBlock, [int]$MaxRetries = 3, [int]$DelaySeconds = 2)
    return [VeaErrorHandler]::RetryExecute($ScriptBlock, $MaxRetries, $DelaySeconds)
}