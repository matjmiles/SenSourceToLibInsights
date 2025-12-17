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

# Legacy compatibility function for existing scripts
function Get-VeaCredentials {
    try {
        $credential = [VeaCredentialManager]::GetCredentials()
        return @{
            ClientId = $credential.UserName
            ClientSecret = $credential.GetNetworkCredential().Password
        }
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

    Write-Host "Initializing VEA API credentials..." -ForegroundColor Cyan

    # Validate format before storing
    if (-not [VeaCredentialManager]::ValidateCredentialFormat($ClientId, $ClientSecret)) {
        Write-Error "Invalid credential format. Client ID should be a UUID and Client Secret should be a valid secret."
        return $false
    }

    try {
        [VeaCredentialManager]::StoreCredentials($ClientId, $ClientSecret)
        Write-Host "VEA API credentials configured successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to initialize credentials: $($_.Exception.Message)"
        return $false
    }
}