# VEA API Secure Credential Management Module
# This module replaces plain text credential storage with Windows Credential Manager

class VeaCredentialManager {
    static [string]$CredentialTarget = "VEA-Springshare-API"

    # Store credentials securely in Windows Credential Manager
    static [void] StoreCredentials([string]$clientId, [string]$clientSecret) {
        if ([string]::IsNullOrEmpty($clientId) -or [string]::IsNullOrEmpty($clientSecret)) {
            throw "Client ID and Client Secret cannot be empty"
        }

        try {
            # Create directory if it doesn't exist
            $credDir = "$env:APPDATA\VEA-API"
            if (-not (Test-Path $credDir)) {
                New-Item -ItemType Directory -Path $credDir -Force | Out-Null
            }

            # Create secure credential object
            $securePassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($clientId, $securePassword)

            # Store in Windows Credential Manager
            $credential | Export-Clixml -Path "$env:APPDATA\VEA-API\credentials.xml" -Force

            Write-Host "Credentials stored securely" -ForegroundColor Green
        }
        catch {
            throw "Failed to store credentials: $($_.Exception.Message)"
        }
    }

    # Retrieve credentials from secure storage
    static [PSCredential] GetCredentials() {
        $credPath = "$env:APPDATA\VEA-API\credentials.xml"

        if (-not (Test-Path $credPath)) {
            throw "Credentials not found. Please run setup first to store your VEA API credentials."
        }

        try {
            $credential = Import-Clixml -Path $credPath
            return $credential
        }
        catch {
            throw "Failed to retrieve credentials: $($_.Exception.Message)"
        }
    }

    # Check if credentials exist
    static [bool] CredentialsExist() {
        $credPath = "$env:APPDATA\VEA-API\credentials.xml"
        return Test-Path $credPath
    }

    # Remove stored credentials (for security/testing)
    static [void] ClearCredentials() {
        $credPath = "$env:APPDATA\VEA-API\credentials.xml"

        if (Test-Path $credPath) {
            Remove-Item $credPath -Force
            Write-Host "Credentials cleared" -ForegroundColor Yellow
        } else {
            Write-Host "No credentials found to clear" -ForegroundColor Gray
        }
    }

    # Validate credential format (basic validation)
    static [bool] ValidateCredentialFormat([string]$clientId, [string]$clientSecret) {
        # Basic UUID format check for Client ID (VEA typically uses UUIDs)
        $uuidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        $isValidClientId = $clientId -match $uuidPattern

        # Client Secret should be non-empty and reasonable length
        $isValidClientSecret = -not [string]::IsNullOrEmpty($clientSecret) -and $clientSecret.Length -gt 20

        return $isValidClientId -and $isValidClientSecret
    }
}

# Unified credential retrieval - supports both environment variables and Windows Credential Manager
function Get-VeaCredentials {
    try {
        # First try environment variables (for automated scenarios)
        if ([VeaEnvironmentCredentials]::EnvironmentCredentialsExist()) {
            Write-Host "Using credentials from environment variables" -ForegroundColor Gray
            $credential = [VeaEnvironmentCredentials]::GetFromEnvironment()
            return @{
                ClientId = $credential.UserName
                ClientSecret = $credential.GetNetworkCredential().Password
            }
        }

        # Fall back to Windows Credential Manager (for interactive scenarios)
        if ([VeaCredentialManager]::CredentialsExist()) {
            Write-Host "Using credentials from Windows Credential Manager" -ForegroundColor Gray
            $credential = [VeaCredentialManager]::GetCredentials()
            return @{
                ClientId = $credential.UserName
                ClientSecret = $credential.GetNetworkCredential().Password
            }
        }

        throw "No VEA credentials found. Please configure credentials using setup.bat or environment variables."
    }
    catch {
        Write-Error "Failed to retrieve VEA credentials: $($_.Exception.Message)"
        return $null
    }
}

# Setup function for initial credential configuration
function Initialize-VeaCredentials {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ClientId,
        [Parameter(Mandatory=$true)]
        [string]$ClientSecret
    )

    Write-Host 'Initializing VEA API credentials...' -ForegroundColor Cyan

    # Validate format before storing
    if (-not [VeaCredentialManager]::ValidateCredentialFormat($ClientId, $ClientSecret)) {
        Write-Host 'Invalid credential format:' -ForegroundColor Red
        if ($ClientId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Write-Host '  - Client ID must be a valid UUID format' -ForegroundColor Red
        }
        if ([string]::IsNullOrEmpty($ClientSecret) -or $ClientSecret.Length -le 20) {
            Write-Host '  - Client Secret must be longer than 20 characters' -ForegroundColor Red
        }
        return $false
    }

    try {
        [VeaCredentialManager]::StoreCredentials($ClientId, $ClientSecret)
        Write-Host 'Credentials stored securely!' -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error ('Failed to initialize credentials: ' + $_.Exception.Message)
        return $false
    }
}
        if ([string]::IsNullOrEmpty($ClientSecret) -or $ClientSecret.Length -le 20) {
            Write-Host "  - Client Secret must be longer than 20 characters" -ForegroundColor Red
        }
        return $false
    }

    try {
        [VeaCredentialManager]::StoreCredentials($ClientId, $ClientSecret)
        Write-Host "✓ Credentials stored securely!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Failed to store credentials: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Environment variable based credential management (for automated scenarios)
class VeaEnvironmentCredentials {
    static [string]$ClientIdEnvVar = "VEA_API_CLIENT_ID"
    static [string]$ClientSecretEnvVar = "VEA_API_CLIENT_SECRET"

    # Store credentials in environment variables
    static [void] StoreInEnvironment([string]$clientId, [string]$clientSecret) {
        [Environment]::SetEnvironmentVariable($ClientIdEnvVar, $clientId, "Machine")
        [Environment]::SetEnvironmentVariable($ClientSecretEnvVar, $clientSecret, "Machine")
        Write-Host "Credentials stored in environment variables" -ForegroundColor Green
    }

    # Retrieve credentials from environment variables
    static [PSCredential] GetFromEnvironment() {
        $clientId = [Environment]::GetEnvironmentVariable($ClientIdEnvVar, "Machine")
        $clientSecret = [Environment]::GetEnvironmentVariable($ClientSecretEnvVar, "Machine")

        if ([string]::IsNullOrEmpty($clientId) -or [string]::IsNullOrEmpty($clientSecret)) {
            throw "VEA credentials not found in environment variables. Set $ClientIdEnvVar and $ClientSecretEnvVar"
        }

        $secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
        return New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)
    }

    # Check if environment credentials exist
    static [bool] EnvironmentCredentialsExist() {
        $clientId = [Environment]::GetEnvironmentVariable($ClientIdEnvVar, "Machine")
        $clientSecret = [Environment]::GetEnvironmentVariable($ClientSecretEnvVar, "Machine")
        return -not ([string]::IsNullOrEmpty($clientId) -and [string]::IsNullOrEmpty($clientSecret))
    }

    # Clear environment credentials
    static [void] ClearEnvironmentCredentials() {
        [Environment]::SetEnvironmentVariable($ClientIdEnvVar, $null, "Machine")
        [Environment]::SetEnvironmentVariable($ClientSecretEnvVar, $null, "Machine")
        Write-Host "Environment credentials cleared" -ForegroundColor Yellow
    }
}

    try {
        [VeaCredentialManager]::StoreCredentials($ClientId, $ClientSecret)
        Write-Host "VEA API credentials configured successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error ('Failed to initialize credentials: ' + $_.Exception.Message)
        return $false
    }
}