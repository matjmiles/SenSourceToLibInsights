@echo off
REM =============================================================================
REM Secure API Setup Script
REM =============================================================================
REM Interactive credential setup for VEA and LibInsights APIs
REM =============================================================================

echo ====================================================
echo VEA TO LIBINSIGHTS SECURE SETUP
echo ====================================================
echo.
echo This script will prompt you to enter your API credentials
echo and store them securely.
echo.
echo Required credentials:
echo   1. VEA API (Client ID and Secret)
echo   2. LibInsights API (Client ID and Secret)
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available or not in PATH
    echo Please ensure PowerShell is installed and accessible
    pause
    exit /b 1
)

REM =============================================================================
REM STEP 1: VEA API Credentials
REM =============================================================================

echo Testing existing VEA credentials...
powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1" >nul 2>&1
if %errorlevel% equ 0 (
    echo VEA credentials already configured and working.
    goto :step2_libinsights
)

echo VEA credentials not found or not working.
echo.
echo Please enter your VEA API credentials:
echo.
set /p "CLIENT_ID=VEA Client ID (UUID format): "
echo.
set /p "CLIENT_SECRET=VEA Client Secret: "

echo.
echo Setting up VEA credentials securely...
powershell -ExecutionPolicy Bypass -File "scripts\setup-automated.ps1" -ClientId "%CLIENT_ID%" -ClientSecret "%CLIENT_SECRET%"

if errorlevel 1 (
    echo.
    echo ERROR: VEA credential setup failed
    echo Please check your credentials and try again.
    pause
    exit /b 1
)

echo VEA credentials saved successfully.

REM =============================================================================
REM STEP 2: LibInsights API Credentials
REM =============================================================================

:step2_libinsights
echo.
echo ====================================================
echo STEP 2: LibInsights API Credentials
echo ====================================================
echo.

REM Check if LibInsights credentials already exist
if not exist "scripts\libinsights_credentials.xml" goto :prompt_libinsights

echo LibInsights credentials file already exists.
set /p "RECONFIGURE=Reconfigure LibInsights credentials? [y/N]: "
if /i "%RECONFIGURE%"=="y" goto :prompt_libinsights
goto :setup_done

:prompt_libinsights
echo.
echo Please enter your LibInsights API credentials:
echo.
set /p "LI_CLIENT_ID=LibInsights Client ID: "
echo.
set /p "LI_CLIENT_SECRET=LibInsights Client Secret: "

echo.
echo Saving LibInsights credentials...
powershell -ExecutionPolicy Bypass -Command "$secureSecret = ConvertTo-SecureString '%LI_CLIENT_SECRET%' -AsPlainText -Force; @{ClientId='%LI_CLIENT_ID%'; ClientSecret=$secureSecret} | Export-Clixml 'scripts\libinsights_credentials.xml'"

if errorlevel 1 (
    echo.
    echo ERROR: LibInsights credential setup failed
    pause
    exit /b 1
)

echo LibInsights credentials saved successfully.

:setup_done
echo.
echo ====================================================
echo ALL CREDENTIALS CONFIGURED!
echo ====================================================
echo.
echo Both VEA and LibInsights credentials are now stored securely.
echo.
echo Next Steps:
echo 1. Test the daily export: powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1"
echo 2. Test the daily import: powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1" -DryRun
echo 3. Schedule run_daily_pipeline.bat in Windows Task Scheduler
echo.
pause
