# Test credential retrieval
. .\VeaCredentialManager.ps1

$creds = Get-VeaCredentials
Write-Host "✓ Credentials retrieved successfully!" -ForegroundColor Green
Write-Host "Client ID: $($creds.ClientId)" -ForegroundColor Gray
Write-Host "Client Secret Length: $($creds.ClientSecret.Length) characters" -ForegroundColor Gray