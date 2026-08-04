# VEA to LibInsights Data Pipeline

Automated extraction of VEA (SenSource) sensor data and import to Springshare LibInsights.

## What This Does

1. **Extracts** hourly traffic data from VEA sensors (5 library entrances)
2. **Converts** the data to LibInsights-ready CSV files
3. **Imports** those CSVs directly to LibInsights via API

All three steps run unattended from a single scheduled task.

## Requirements

- Windows 10/11 or Windows Server 2016+
- Windows PowerShell 5.1 (ships with Windows — nothing to install)
- Outbound HTTPS to `auth.sensourceinc.com`, `vea.sensourceinc.com`, and `byui.libinsight.com`
- API credentials for both VEA and LibInsights

## Quick Start

```batch
REM 1. Clone repository
git clone https://github.com/byui-library/SenSourceToLibInsights.git
cd SenSourceToLibInsights

REM 2. Configure credentials (prompts for VEA + LibInsights)
setup.bat

REM 3. Test daily export
powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1"

REM 4. Test daily import (dry run — writes nothing)
powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1" -DryRun
```

If both tests look right, run the import for real and then schedule
`run_daily_pipeline.bat`.

## Server Deployment & Task Scheduler

**For production server setup with automated nightly runs, see:**

📋 **[docs/SERVER-DEPLOYMENT.md](docs/SERVER-DEPLOYMENT.md)**

This guide covers:
- Server prerequisites
- Credential configuration (VEA + LibInsights)
- Task Scheduler setup (step-by-step)
- Troubleshooting

## Daily Automation

The **`run_daily_pipeline.bat`** script runs nightly to:
1. Extract the **previous day's** VEA data (a complete 24-hour window)
2. Import it to LibInsights via API

Schedule this in Windows Task Scheduler to run after midnight (e.g., 2:00 AM).
Each run appends to `logs/daily-export-YYYY-MM-DD.log` and
`logs/daily-import-YYYY-MM-DD.log`.

## Project Structure

```
SenSourceToLibInsights/
├── run_daily_pipeline.bat            # ← SCHEDULE THIS IN TASK SCHEDULER
├── setup.bat                         # Configure VEA + LibInsights credentials
├── run_full_pipeline.bat             # Interactive: extract year-to-date + import
├── run_export.bat                    # Interactive: extract only
├── run_import.bat                    # Interactive: import existing CSVs (menu)
├── scripts/
│   ├── Daily-VEA-Export.ps1          # Exports previous day's data, with logging
│   ├── Daily-LibInsights-Import.ps1  # Imports CSVs to LibInsights, with logging
│   ├── VEA-Zone-Extractor.ps1        # Core extraction (custom date ranges)
│   ├── LibInsights-Importer.ps1      # Core import logic
│   ├── LibInsights-API-Explorer.ps1  # Credential setup + endpoint discovery
│   ├── setup-automated.ps1           # Non-interactive VEA credential setup
│   ├── test-credentials.ps1          # Verify VEA credentials and connectivity
│   └── Vea*.ps1                      # Shared credential/validation/error modules
├── output/csv/                       # Generated CSV files
├── output/json/                      # Raw VEA API responses (for debugging)
├── logs/                             # Daily execution logs
├── docs/                             # Detailed documentation
└── archive/                          # Superseded development scripts (reference only)
```

## Sensor Mapping

| VEA Sensor | LibInsights Gate ID | Location |
|------------|---------------------|----------|
| McKay_Library_Level_1_Main_Entrance_1 | 12 | West Wing Level 1 East Side |
| McKay_Library_Level_1_New_Entrance | 13 | West Wing Level 1 West Side |
| McKay_Library_Level_2_Stairs | 14 | West Wing Level 2 Stairs |
| McKay_Library_Level_3_Bridge | 15 | West Wing Level 3 Bridge |
| McKay_Library_Level_3_Stairs | 16 | West Wing Level 3 Stairs |

## Output Format

CSVs are **hourly** (one row per sensor per hour), UTF-8 without BOM:

```csv
# output/csv/gate_counts/Gate Count West Wing Level 1 East Side.csv
date,gate_start
2026-01-15 08:00,42

# output/csv/occupancy/Occupancy West Wing Level 1 East Side.csv
date,gate_start,gate_end
2026-01-15 08:00,42,38
```

`gate_start` is entries, `gate_end` is exits. Each extraction run overwrites these
files, so import before the next extraction.

## Manual Operations

```powershell
# Export a specific date (e.g., to backfill a missed night)
.\scripts\Daily-VEA-Export.ps1 -SpecificDate "2026-01-15"

# Export a custom date range (ISO-8601, UTC)
.\scripts\VEA-Zone-Extractor.ps1 -StartDate "2026-01-01T00:00:00Z" -EndDate "2026-01-31T23:59:59Z"

# Import with options
.\scripts\Daily-LibInsights-Import.ps1 -DryRun          # Preview only
.\scripts\Daily-LibInsights-Import.ps1 -GateCountsOnly  # Gate counts only
.\scripts\Daily-LibInsights-Import.ps1 -OccupancyOnly   # Occupancy only

# Verify VEA credentials and API connectivity
.\scripts\test-credentials.ps1 -Detailed
```

Re-running an import is safe — the LibInsights API rejects duplicate records.

## Documentation

- [Server Deployment Guide](docs/SERVER-DEPLOYMENT.md) — production setup & Task Scheduler
- [Scripts Reference](docs/SCRIPTS.md) — detailed script documentation
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common issues and solutions
- [LibInsights API Reference](docs/LibInsights-API.md) — endpoint list
- [PowerShell Guide](docs/POWERSHELL_GUIDE.md) — primer for maintainers new to PowerShell
- [CLAUDE.md](CLAUDE.md) — architecture and conventions (for AI coding agents and new maintainers)

## Security

- **System of record**: both credential sets are stored in **LastPass**. Retrieve
  them from the library's LastPass vault when setting up a machine — `setup.bat`
  prompts for all four values.
- **VEA credentials**: encrypted with DPAPI at `%APPDATA%\VEA-API\credentials.xml`
  (falls back to the `VEA_API_CLIENT_ID` / `VEA_API_CLIENT_SECRET` machine
  environment variables for service accounts)
- **LibInsights credentials**: encrypted XML file (`scripts/libinsights_credentials.xml`, gitignored)
- **No plain text secrets** in repository

Both credential files are encrypted to the Windows account that created them and
cannot be decrypted by a different account — or copied to another machine. On a
new server, re-run `setup.bat` with the values from LastPass rather than copying
the files across. See
[SERVER-DEPLOYMENT.md](docs/SERVER-DEPLOYMENT.md#credentials-not-found) if the
scheduled task runs as a different user.
