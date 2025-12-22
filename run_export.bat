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
echo Step 2: Data extraction complete - CSV files generated
echo -------------------------------------------------------
echo Individual sensor CSV files have been created in both formats:
echo   - Occupancy files: output\csv\occupancy\ (date, gate_start, gate_end) 
echo   - Gate counts files: output\csv\gate_counts\ (date, gate_start)
echo.
echo ====================================================
echo EXPORT COMPLETE!
echo ====================================================
echo.
echo Individual sensor CSV files have been created in both formats:
echo   - Occupancy: output\csv\occupancy\ (date, gate_start, gate_end)
echo   - Gate counts: output\csv\gate_counts\ (date, gate_start)
echo.
echo These files are ready for Springshare LibInsights import!
echo.
echo Files created:
powershell -Command "Get-ChildItem 'output\csv\occupancy\*springshare_import.csv' | Measure-Object | Select-Object -ExpandProperty Count"
echo occupancy files (date, gate_start, gate_end)
echo.
powershell -Command "Get-ChildItem 'output\csv\gate_counts\*gate_counts.csv' | Measure-Object | Select-Object -ExpandProperty Count"
echo gate counts files (date, gate_start)
echo.
pause