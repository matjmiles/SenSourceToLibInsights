# VEA API Automated Setup Script
# This script sets up credentials for automated/non-interactive scenarios

param(
    [string]$ClientId,
    [string]$ClientSecret,
    [switch]$UseEnvironmentVariables,
    [switch]$ResetCredentials
)

# Import the credential manager module
$credentialManagerPath = Join-Path $PSScriptRoot "VeaCredentialManager.ps1"
if (-not (Test-Path $credentialManagerPath)) {
    Write-Error "Credential manager module not found: $credentialManagerPath"
    exit 1
}

. $credentialManagerPath

Write-Host "=======================================" -ForegroundColor Green
Write-Host "VEA API AUTOMATED SETUP" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""

# Handle reset credentials
if ($ResetCredentials) {
    Write-Host "Resetting all stored credentials..." -ForegroundColor Yellow
    [VeaCredentialManager]::ClearCredentials()
    [VeaEnvironmentCredentials]::ClearEnvironmentCredentials()
    Write-Host "All credentials cleared." -ForegroundColor Green
    exit 0
}

# Check if credentials provided as parameters
if ($ClientId -and $ClientSecret) {
    Write-Host "Setting up credentials from parameters..." -ForegroundColor Cyan

    # Validate format
    if (-not [VeaCredentialManager]::ValidateCredentialFormat($ClientId, $ClientSecret)) {
        Write-Error "Invalid credential format provided"
        exit 1
    }

    # Store based on preference
    if ($UseEnvironmentVariables) {
        [VeaEnvironmentCredentials]::StoreInEnvironment($ClientId, $ClientSecret)
        Write-Host "Credentials stored in environment variables for automated use." -ForegroundColor Green
    } else {
        [VeaCredentialManager]::StoreCredentials($ClientId, $ClientSecret)
        Write-Host "Credentials stored in Windows Credential Manager." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Setup complete! You can now run automated tasks." -ForegroundColor Green
    exit 0
}

# Interactive setup (fallback)
Write-Host "No credentials provided as parameters." -ForegroundColor Yellow
Write-Host "Use one of these methods:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. For automated scripts:" -ForegroundColor White
Write-Host "   .\setup-automated.ps1 -ClientId 'your-id' -ClientSecret 'your-secret' -UseEnvironmentVariables" -ForegroundColor Gray
Write-Host ""
Write-Host "2. For interactive setup:" -ForegroundColor White
Write-Host "   .\setup-credentials.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Set environment variables manually:" -ForegroundColor White
Write-Host "   `$env:VEA_API_CLIENT_ID = 'your-id'" -ForegroundColor Gray
Write-Host "   `$env:VEA_API_CLIENT_SECRET = 'your-secret'" -ForegroundColor Gray
Write-Host ""

exit 1