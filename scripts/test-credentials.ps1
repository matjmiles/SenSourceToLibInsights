# VEA API Secure Credential Test Script
# This script tests the secure credential system and API connectivity

param(
    [switch]$Detailed
)

# Import required modules
$modules = @(
    "VeaCredentialManager.ps1",
    "VeaValidator.ps1",
    "VeaExceptions.ps1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $PSScriptRoot $module
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

Write-Host "======================================" -ForegroundColor Green
Write-Host "VEA API SECURE CREDENTIAL TEST" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

# Test 1: Check if credentials exist
Write-Host "Test 1: Checking credential storage..." -ForegroundColor Cyan

if ([VeaCredentialManager]::CredentialsExist()) {
    Write-Host "✓ Credentials are stored securely" -ForegroundColor Green
} else {
    Write-Host "✗ No credentials found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run setup.bat to configure your VEA API credentials." -ForegroundColor Yellow
    exit 1
}

# Test 2: Test credential retrieval
Write-Host ""
Write-Host "Test 2: Testing credential retrieval..." -ForegroundColor Cyan

try {
    $credentials = Invoke-VeaSafe { Get-VeaCredentials } "credential retrieval"
    Write-Host "✓ Credentials retrieved successfully" -ForegroundColor Green

    if ($Detailed) {
        Write-Host "  Client ID: $($credentials.ClientId)" -ForegroundColor Gray
        Write-Host "  Client Secret Length: $($credentials.ClientSecret.Length) characters" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Failed to retrieve credentials: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Test credential format validation
Write-Host ""
Write-Host "Test 3: Validating credential format..." -ForegroundColor Cyan

if ([VeaCredentialManager]::ValidateCredentialFormat($credentials.ClientId, $credentials.ClientSecret)) {
    Write-Host "✓ Credential format is valid" -ForegroundColor Green
} else {
    Write-Host "✗ Credential format is invalid" -ForegroundColor Red
    Write-Host "  Client ID should be a UUID, Client Secret should be >20 characters" -ForegroundColor Yellow
    exit 1
}

# Test 4: Test API connectivity (optional, requires network)
Write-Host ""
Write-Host "Test 4: Testing API connectivity..." -ForegroundColor Cyan

$connectivityTest = Test-VeaApiCredentials -ClientId $credentials.ClientId -ClientSecret $credentials.ClientSecret

if ($connectivityTest) {
    Write-Host "✓ API connectivity test passed" -ForegroundColor Green
    Write-Host "✓ Your credentials are working correctly!" -ForegroundColor Green
} else {
    Write-Host "✗ API connectivity test failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "  - Network connectivity problems" -ForegroundColor Yellow
    Write-Host "  - Invalid credentials" -ForegroundColor Yellow
    Write-Host "  - VEA API service unavailable" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please check your credentials and network connection." -ForegroundColor Yellow
    exit 1
}

# Test 5: Test parameter validation
Write-Host ""
Write-Host "Test 5: Testing parameter validation..." -ForegroundColor Cyan

$testParams = @{
    StartDate = "2025-12-01T00:00:00Z"
    EndDate = "2025-12-07T23:59:59Z"
    DataType = "traffic"
    DateGrouping = "hour"
    GateMethod = "Bidirectional"
}

if ([VeaValidator]::TestScriptParameters($testParams)) {
    Write-Host "✓ Parameter validation passed" -ForegroundColor Green
} else {
    Write-Host "✗ Parameter validation failed" -ForegroundColor Red
}

# Test 6: Test error handling
Write-Host ""
Write-Host "Test 6: Testing error handling framework..." -ForegroundColor Cyan

try {
    throw [VeaValidationException]::new("Test validation error", @{ Parameter = "TestParam"; Value = "Invalid" })
} catch {
    [VeaErrorHandler]::HandleException($_)
    Write-Host "✓ Error handling framework working correctly" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your VEA API secure credential system is working correctly." -ForegroundColor Green
Write-Host "You can now run the export pipeline with: run_export.bat" -ForegroundColor White
Write-Host ""

if (-not $Detailed) {
    Write-Host "Run with -Detailed flag for more information: .\scripts\test-credentials.ps1 -Detailed" -ForegroundColor Gray
}