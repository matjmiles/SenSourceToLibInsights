@echo off
REM VEA to Springshare LibInsights Export Pipeline
REM This batch file runs the complete data extraction and conversion process

echo ====================================================
echo VEA TO SPRINGSHARE LIBINSIGHTS EXPORT PIPELINE
echo ====================================================
echo.

REM Prompt for date range
echo Please enter the date range for data extraction:
echo.
set /p START_DATE="Start date (yyyy-mm-dd): "
set /p END_DATE="End date (yyyy-mm-dd): "
echo.

REM Basic validation - check if dates were provided
if "%START_DATE%"=="" (
    echo ERROR: Start date is required
    pause
    exit /b 1
)
if "%END_DATE%"=="" (
    echo ERROR: End date is required
    pause
    exit /b 1
)

echo Using date range: %START_DATE% to %END_DATE%
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available or not in PATH
    echo Please ensure PowerShell is installed and accessible
    pause
    exit /b 1
)

echo Step 1: Extracting individual sensor data from VEA API...
echo --------------------------------------------------------
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1" -StartDate "%START_DATE%T00:00:00Z" -EndDate "%END_DATE%T23:59:59Z"

if errorlevel 1 (
    echo ERROR: VEA data extraction failed
    echo Please check your API credentials and network connection
    pause
    exit /b 1
)

echo.
echo Step 2: Converting zone data to individual sensor CSVs...
echo ---------------------------------------------------------
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Generate-All-Individual-CSVs.ps1" -GateMethod "Bidirectional"

if errorlevel 1 (
    echo ERROR: CSV conversion failed
    echo Please check the zone data files in output\json folder
    pause
    exit /b 1
)

echo.
echo ====================================================
echo EXPORT COMPLETE!
echo ====================================================
echo.
echo Individual sensor CSV files have been created in:
echo   output\csv\
echo.
echo These files are ready for Springshare LibInsights import!
echo.
echo Files created:
dir "output\csv\*individual_springshare_import.csv" /b
echo.
pause