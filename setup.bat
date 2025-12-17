@echo off
REM Secure VEA API Setup Script
REM Interactive credential setup for first-time configuration

echo ====================================================
echo VEA TO SPRINGSHARE SECURE SETUP
echo ====================================================
echo.
echo This script will prompt you to enter your VEA API credentials
echo and store them securely in Windows Credential Manager.
echo.
echo For automated/scripted setup, use:
echo   .\scripts\setup-automated.ps1 -ClientId "your-id" -ClientSecret "your-secret" -UseEnvironmentVariables
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available or not in PATH
    echo Please ensure PowerShell is installed and accessible
    pause
    exit /b 1
)

REM Check if already configured
powershell -ExecutionPolicy Bypass -Command "& { . 'scripts\VeaCredentialManager.ps1'; if ([VeaCredentialManager]::CredentialsExist() -or [VeaEnvironmentCredentials]::EnvironmentCredentialsExist()) { Write-Host 'Credentials already configured!' -ForegroundColor Green; exit 0 } }" 2>nul
if %errorlevel% equ 0 (
    echo Credentials are already configured.
    echo To reconfigure, run: .\scripts\setup-automated.ps1 -ResetCredentials
    echo Then run this setup again.
    echo.
    pause
    exit /b 0
)

REM Run the secure credential setup
echo Starting interactive credential setup...
echo.
echo You will be prompted to enter:
echo - Client ID: Your VEA API Client ID (UUID format like 12345678-1234-1234-1234-123456789012)
echo - Client Secret: Your VEA API Client Secret (long string, 30+ characters)
echo.
powershell -ExecutionPolicy Bypass -File "scripts\setup-credentials.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: Credential setup failed
    echo Please check your credentials and try again
    echo.
    echo For automated setup options, see README.md
    pause
    exit /b 1
)

echo.
echo ====================================================
echo SETUP COMPLETE!
echo ====================================================
echo.
echo Your VEA API credentials are now stored securely.
echo You can now run the export pipeline with: run_export.bat
echo.
echo For Task Scheduler automation, use environment variables:
echo   .\scripts\setup-automated.ps1 -ClientId "your-id" -ClientSecret "your-secret" -UseEnvironmentVariables
echo.
pause