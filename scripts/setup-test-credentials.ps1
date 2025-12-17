# Quick setup script for test credentials
$testClientId = 'f01cc7bb-e060-4965-bcda-612e2dc8d294'
$testClientSecret = '3b710165-fd3c-49a5-a869-4ed8a7eba99d'

. .\VeaCredentialManager.ps1

[VeaCredentialManager]::StoreCredentials($testClientId, $testClientSecret)
Write-Host "✓ Test credentials stored securely!" -ForegroundColor Green
Write-Host "Client ID: $testClientId" -ForegroundColor Gray