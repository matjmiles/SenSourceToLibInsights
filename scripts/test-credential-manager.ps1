# Simple test of credential manager
try {
    . "$PSScriptRoot\VeaCredentialManager.ps1"
    Write-Host "Credential manager loaded successfully" -ForegroundColor Green

    # Test the ValidateCredentialFormat method
    $result = [VeaCredentialManager]::ValidateCredentialFormat("f01cc7bb-e060-4965-bcda-612e2dc8d294", "3b710165-fd3c-49a5-a869-4ed8a7eba99d")
    Write-Host "Validation result: $result" -ForegroundColor Cyan

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
}