@echo off
REM VEA to Springshare LibInsights Export Pipeline
REM This batch file runs the complete data extraction and conversion process

echo ====================================================
echo VEA TO SPRINGSHARE LIBINSIGHTS EXPORT PIPELINE
echo ====================================================
echo.
echo This will extract data from the beginning of the current year
echo up to the current date automatically.
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
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1"

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
powershell -Command "Get-ChildItem 'output\csv\*individual_springshare_import.csv' | Measure-Object | Select-Object -ExpandProperty Count"
echo.
pause