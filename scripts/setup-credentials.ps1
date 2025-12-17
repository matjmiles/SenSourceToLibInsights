# VEA API Secure Setup Script
# This script replaces the plain text config.ps1 with secure credential storage

param(
    [switch]$ResetCredentials,
    [switch]$CheckCredentials
)

# Import the credential manager module
$credentialManagerPath = Join-Path $PSScriptRoot "VeaCredentialManager.ps1"
if (-not (Test-Path $credentialManagerPath)) {
    Write-Error "Credential manager module not found: $credentialManagerPath"
    exit 1
}

. $credentialManagerPath

Write-Host "=======================================" -ForegroundColor Green
Write-Host "VEA API SECURE CREDENTIAL SETUP" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""

# Handle reset credentials option
if ($ResetCredentials) {
    Write-Host "Resetting stored credentials..." -ForegroundColor Yellow
    [VeaCredentialManager]::ClearCredentials()
    Write-Host "Credentials reset. Please run setup again to configure new credentials." -ForegroundColor Green
    exit 0
}

# Handle check credentials option
if ($CheckCredentials) {
    Write-Host "Checking credential status..." -ForegroundColor Cyan

    if ([VeaCredentialManager]::CredentialsExist()) {
        Write-Host "✓ Credentials are stored securely" -ForegroundColor Green
        try {
            $creds = Get-VeaCredentials
            Write-Host "✓ Credentials can be retrieved" -ForegroundColor Green
            Write-Host "Client ID: $($creds.ClientId)" -ForegroundColor Gray
        }
        catch {
            Write-Host "✗ Credentials cannot be retrieved: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ No credentials stored" -ForegroundColor Red
    }
    exit 0
}

# Check if credentials already exist
if ([VeaCredentialManager]::CredentialsExist()) {
    Write-Host "Credentials are already configured." -ForegroundColor Green
    Write-Host ""

    $overwrite = Read-Host "Do you want to update the existing credentials? (y/N)"
    if ($overwrite -notmatch "^[Yy]$") {
        Write-Host "Setup cancelled. Existing credentials preserved." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Updating existing credentials..." -ForegroundColor Cyan
}

# Collect credentials from user
Write-Host "Please enter your VEA API credentials:" -ForegroundColor Cyan
Write-Host "These will be stored securely in Windows Credential Manager." -ForegroundColor Gray
Write-Host ""

$clientId = ""
$clientSecret = ""

# Loop until valid credentials are provided
$validCredentials = $false
$attempts = 0
$maxAttempts = 3

while (-not $validCredentials -and $attempts -lt $maxAttempts) {
    $attempts++

    if ($attempts -gt 1) {
        Write-Host "Invalid credentials format. Please try again." -ForegroundColor Yellow
        Write-Host ""
    }

    $clientId = Read-Host "Client ID (UUID format)"
    $clientSecret = Read-Host "Client Secret" -AsSecureString

    # Convert secure string to plain text for validation
    $plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret)
    )

    # Validate credential format
    if ([VeaCredentialManager]::ValidateCredentialFormat($clientId, $plainSecret)) {
        $validCredentials = $true
    } else {
        Write-Host "Credential validation failed:" -ForegroundColor Red
        if ($clientId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Write-Host "  - Client ID must be a valid UUID format" -ForegroundColor Red
        }
        if ([string]::IsNullOrEmpty($plainSecret) -or $plainSecret.Length -le 20) {
            Write-Host "  - Client Secret must be longer than 20 characters" -ForegroundColor Red
        }
    }
}

if (-not $validCredentials) {
    Write-Error "Maximum attempts exceeded. Setup cancelled."
    exit 1
}

# Store credentials securely
Write-Host ""
Write-Host "Storing credentials securely..." -ForegroundColor Cyan

try {
    Initialize-VeaCredentials -ClientId $clientId -ClientSecret $plainSecret

    Write-Host ""
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "VEA API credentials have been configured securely." -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now run the export pipeline with: run_export.bat" -ForegroundColor White
    Write-Host ""
    Write-Host "To check credentials later: .\scripts\setup-credentials.ps1 -CheckCredentials" -ForegroundColor Gray
    Write-Host "To reset credentials: .\scripts\setup-credentials.ps1 -ResetCredentials" -ForegroundColor Gray

} catch {
    Write-Error "Failed to store credentials: $($_.Exception.Message)"
    exit 1
}