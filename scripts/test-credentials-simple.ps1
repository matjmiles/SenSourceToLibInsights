# Quick credential verification script
# This script checks if credentials are properly configured

# Import the credential manager module
. "VeaCredentialManager.ps1"

Write-Host "Checking VEA API credentials..." -ForegroundColor Cyan

if ([VeaCredentialManager]::CredentialsExist()) {
    Write-Host "✓ Credentials are stored securely" -ForegroundColor Green
    try {
        $creds = Get-VeaCredentials
        Write-Host "✓ Credentials can be retrieved" -ForegroundColor Green
        Write-Host "Client ID: $($creds.ClientId)" -ForegroundColor Gray

        # Test API connectivity
        Write-Host "Testing API connectivity..." -ForegroundColor Cyan
        $testResult = Test-VeaApiCredentials -ClientId $creds.ClientId -ClientSecret $creds.ClientSecret
        if ($testResult) {
            Write-Host "✓ API connectivity test passed!" -ForegroundColor Green
            Write-Host "Credentials are working correctly." -ForegroundColor Green
        } else {
            Write-Host "✗ API connectivity test failed" -ForegroundColor Red
            Write-Host "Please check your credentials and network connection." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Error retrieving credentials: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ No credentials configured" -ForegroundColor Red
    Write-Host "Please run setup.bat to configure your VEA API credentials." -ForegroundColor Yellow
}