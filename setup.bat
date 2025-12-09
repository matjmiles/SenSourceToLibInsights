@echo off
REM Setup script for VEA to Springshare LibInsights Pipeline

echo ====================================================
echo VEA TO SPRINGSHARE SETUP
echo ====================================================
echo.

echo Checking for configuration file...
if exist "config.ps1" (
    echo ✓ Configuration file found: config.ps1
    echo.
    echo Ready to run! Execute: run_export.bat
) else (
    echo ✗ Configuration file NOT found
    echo.
    echo SETUP REQUIRED:
    echo 1. Copy config.example.ps1 to config.ps1
    echo 2. Edit config.ps1 with your VEA API credentials
    echo 3. Run this setup script again to verify
    echo.
    echo Creating config.ps1 from template...
    copy "config.example.ps1" "config.ps1"
    echo.
    echo ✓ Created config.ps1
    echo ⚠ IMPORTANT: Edit config.ps1 with your actual VEA API credentials
    echo.
    echo Your credentials are needed:
    echo - Client ID
    echo - Client Secret  
    echo - Site ID
    echo.
    echo After editing config.ps1, run: run_export.bat
)

echo.
pause