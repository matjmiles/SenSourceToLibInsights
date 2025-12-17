@echo off
REM Secure VEA API Setup Script
REM This script uses secure credential storage instead of plain text files

echo ====================================================
echo VEA TO SPRINGSHARE SECURE SETUP
echo ====================================================
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available or not in PATH
    echo Please ensure PowerShell is installed and accessible
    pause
    exit /b 1
)

REM Run the secure credential setup
echo Starting secure credential setup...
echo.
powershell -ExecutionPolicy Bypass -File "scripts\setup-credentials.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: Credential setup failed
    echo Please check your credentials and try again
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
pause