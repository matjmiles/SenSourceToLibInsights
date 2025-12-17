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

REM Test if credentials exist AND work
echo Testing existing credentials...
powershell -ExecutionPolicy Bypass -File "scripts\test-credentials-simple.ps1" >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo ====================================================
    echo CREDENTIALS ALREADY CONFIGURED AND WORKING!
    echo ====================================================
    echo.
    echo Your VEA API credentials are properly set up.
    echo You can now run the export pipeline with: run_export.bat
    echo.
    pause
    exit /b 0
)

echo Existing credentials not found or not working.
echo Setting up new credentials...

REM Get credentials from user
echo.
echo Please enter your VEA API credentials:
echo.
set /p "CLIENT_ID=Client ID (UUID format): "
echo.
set /p "CLIENT_SECRET=Client Secret: "

echo.
echo Setting up credentials securely...
powershell -ExecutionPolicy Bypass -File "scripts\setup-automated.ps1" -ClientId "%CLIENT_ID%" -ClientSecret "%CLIENT_SECRET%"

if errorlevel 1 (
    echo.
    echo ERROR: Credential setup failed
    echo Please check your credentials and try again.
    echo.
    echo Make sure you entered:
    echo - A valid Client ID (UUID format like 12345678-1234-1234-1234-123456789012)
    echo - A valid Client Secret (long string, typically 30+ characters)
    echo.
    pause
    exit /b 1
)

echo.
echo ====================================================
echo SETUP COMPLETE!
echo ====================================================
echo.
echo Your VEA API credentials are now stored securely in Windows Credential Manager.
echo.
echo Next Steps:
echo 1. Run the export pipeline: run_export.bat
echo 2. Set up Task Scheduler for automation (see README.md)
echo.
echo Your credentials are encrypted and will work across computer restarts.
echo.
pause