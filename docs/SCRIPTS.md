# Scripts Documentation

This document explains how each script works in the VEA to LibInsights data pipeline.

## Overview

The pipeline has two layers:

- **Core scripts** do the real work and take explicit parameters:
  `VEA-Zone-Extractor.ps1` (extract) and `LibInsights-Importer.ps1` (import).
- **Daily wrappers** add date defaulting and timestamped logging, then call the
  core scripts: `Daily-VEA-Export.ps1` and `Daily-LibInsights-Import.ps1`.

Production automation uses the daily wrappers via `run_daily_pipeline.bat`.
Ad-hoc work usually calls the core scripts directly.

---

## Daily Automation Scripts

### 1. Daily-VEA-Export.ps1

**Purpose**: Export a single day's VEA sensor data to CSV, with logging suitable for
unattended Task Scheduler runs.

**How it Works**:
1. Resolves the target date (yesterday by default)
2. Builds a full-day UTC window: `T00:00:00Z` to `T23:59:59Z`
3. Invokes `VEA-Zone-Extractor.ps1` with that range
4. Verifies CSV files were produced in both output directories
5. Writes every step to `logs/daily-export-YYYY-MM-DD.log`

**Parameters**:
- `-DaysBack <int>` — how many days back to export (default: `1`, i.e. yesterday)
- `-SpecificDate "yyyy-MM-dd"` — export one exact date; overrides `-DaysBack`

**Usage**:
```powershell
.\Daily-VEA-Export.ps1                          # Yesterday
.\Daily-VEA-Export.ps1 -DaysBack 2              # Two days ago
.\Daily-VEA-Export.ps1 -SpecificDate "2026-01-15"
```

**Exit codes**: `0` on success, `1` on invalid date, missing extractor, or
extraction failure. If no CSVs are found it logs a `WARN` but still exits `0`.

---

### 2. Daily-LibInsights-Import.ps1

**Purpose**: Import the CSVs currently in `output/csv/` into LibInsights, with
logging suitable for unattended runs.

**How it Works**:
1. Counts CSV files in `output/csv/gate_counts/` and `output/csv/occupancy/`
2. Fails fast with exit code `1` if there is nothing to import
3. Invokes `LibInsights-Importer.ps1` with the matching switches
4. Writes every step to `logs/daily-import-YYYY-MM-DD.log`

**Parameters**:
- `-GateCountsOnly` — import only `output/csv/gate_counts/`
- `-OccupancyOnly` — import only `output/csv/occupancy/`
- `-DryRun` — preview record counts and a sample record; sends nothing

**Usage**:
```powershell
.\Daily-LibInsights-Import.ps1 -DryRun    # Always do this first
.\Daily-LibInsights-Import.ps1            # Full import
```

Re-running is safe: the LibInsights API rejects duplicate records.

---

## Core Scripts

### 3. VEA-Zone-Extractor.ps1

**Purpose**: Main data extraction script. Retrieves VEA sensor data and generates
both JSON backups and LibInsights-ready CSV files.

**How it Works**:
1. **Module loading**: dot-sources `VeaCredentialManager.ps1`, `VeaValidator.ps1`,
   and `VeaExceptions.ps1` from the same directory
2. **Parameter validation**: `[VeaValidator]::TestScriptParameters()` checks the
   date range and enum-like parameters before any network call
3. **Credentials**: `Get-VeaCredentials` reads from environment variables first,
   then the encrypted local store
4. **Authentication**: OAuth 2.0 client-credentials grant against
   `https://auth.sensourceinc.com/oauth/token`
5. **Zone discovery**: `GET /zone` returns every zone; the list is saved to
   `output/json/vea_zones_list.json`
6. **Data extraction**: for each zone, `GET /data/traffic?entityType=zone&zoneId=...`
7. **Zone filtering**: the API returns records for *all* zones regardless of the
   `zoneId` parameter, so records are filtered client-side on `record.zoneId`
8. **CSV generation**: writes one gate-count and one occupancy CSV per sensor

**Default Behavior** (no parameters):
- Extracts **January 1 of the current year through the end of today**, in UTC
- Retrieves credentials from secure storage — no manual configuration
- Generates friendly file names using the "West Wing" convention
- Creates both CSV formats: gate counts and occupancy

**Custom Date Range**:
```powershell
.\VEA-Zone-Extractor.ps1 -StartDate "2026-01-01T00:00:00Z" -EndDate "2026-01-31T23:59:59Z"
```

**Parameters**:
- `-StartDate` — ISO-8601 UTC start (optional; defaults to Jan 1 of the current year)
- `-EndDate` — ISO-8601 UTC end (optional; defaults to end of today)
- `-DataType` — data type to extract (default: `traffic`)
- `-DateGrouping` — grouping interval (default: `hour`)
- `-GateMethod` — `Bidirectional` (default) or `Manual`

`-GateMethod Manual` writes `entries + exits` into `gate_start` and leaves
`gate_end` empty, for LibInsights datasets configured for manual gate counts.
The gate-count CSV is unaffected by this switch.

**Output Files**:
- `output/json/{SensorName}_zone_data.json` — raw zone response plus extraction metadata
- `output/json/vea_zones_list.json` — full zone list from the API
- `output/csv/gate_counts/Gate Count West Wing Level X [Location].csv`
- `output/csv/occupancy/Occupancy West Wing Level X [Location].csv`

Each run **overwrites** these files. Import before extracting again.

---

### 4. LibInsights-Importer.ps1

**Purpose**: Import VEA gate count and occupancy data from CSV files directly into
LibInsights via API.

**How it Works**:
1. **Credentials**: reads `scripts/libinsights_credentials.xml` (encrypted `Clixml`)
2. **Authentication**: OAuth 2.0 client-credentials grant against
   `POST /v1.0/oauth/token`, form-encoded
3. **File discovery**: scans `output/csv/gate_counts/` and `output/csv/occupancy/`
4. **Gate mapping**: matches each filename against the gate-ID table below
5. **Batch import**: posts records in batches (default 100) with a 200 ms pause
   between batches to avoid rate limiting
6. **Reporting**: prints per-file and grand-total success/failure counts

**Usage**:
```powershell
.\LibInsights-Importer.ps1                    # Import all data
.\LibInsights-Importer.ps1 -GateCountsOnly    # Gate counts only
.\LibInsights-Importer.ps1 -OccupancyOnly     # Occupancy only
.\LibInsights-Importer.ps1 -DryRun            # Preview without importing
.\LibInsights-Importer.ps1 -TestSingle        # Send only the first record per file
.\LibInsights-Importer.ps1 -BatchSize 50      # Smaller batches
```

**Gate ID Mapping**:

| CSV Pattern | LibInsights Gate ID | VEA Sensor |
|-------------|---------------------|------------|
| West Wing Level 1 East Side | 12 | McKay_Library_Level_1_Main_Entrance_1 |
| West Wing Level 1 West Side | 13 | McKay_Library_Level_1_New_Entrance |
| West Wing Level 2 Stairs | 14 | McKay_Library_Level_2_Stairs |
| West Wing Level 3 Bridge | 15 | McKay_Library_Level_3_Bridge |
| West Wing Level 3 Stairs | 16 | McKay_Library_Level_3_Stairs |

A file whose name matches no pattern is skipped with a warning.

**API Details**:
- **Base URL**: `https://byui.libinsight.com/v1.0`
- **Endpoint**: `POST /gate-count/{dataset_id}/save`
- **Dataset ID**: `43702` (SenSource Gate Count By Entrance)
- **Payload**: JSON array of `{ gate_id, date, gate_start, gate_end? }`

> **Note:** Both gate-count and occupancy CSVs are posted to dataset `43702`.
> Occupancy rows differ only by carrying a `gate_end` value. The scripts also
> declare `$OccupancyDatasetId = "43600"` (SenSource Occupancy Rates), but it is
> **not currently used by the importer** — don't assume occupancy lands in 43600.

**Data Handling**:
- Zero-traffic rows (`gate_start = 0` **and** `gate_end = 0`) are skipped on
  occupancy imports; the API returns 400 Bad Request for them. Gate-count imports
  do not apply this filter, since they have no `gate_end`.
- Duplicate records are rejected by the API, which makes re-imports effectively
  idempotent — but they will be counted as failures in the summary.

---

## Support Scripts

### 5. LibInsights-API-Explorer.ps1

**Purpose**: Save LibInsights credentials and explore/verify API endpoints.

**Usage**:
```powershell
.\LibInsights-API-Explorer.ps1 -SaveCredentials   # First-time credential setup
.\LibInsights-API-Explorer.ps1 -TestOnly          # Test authentication only
.\LibInsights-API-Explorer.ps1                    # Full exploration
```

`setup.bat` writes the same credential file, so you only need `-SaveCredentials`
if you are reconfiguring LibInsights on its own.

**Output Files**:
- `output/json/libinsights_gate_count_libraries.json` — gate configurations
  (this is where the gate IDs in the table above come from)
- `output/json/libinsights_gate_count_overview.json` — dataset overview
- `output/json/libinsights_occupancy_fields.json` — occupancy field definitions
- `output/json/libinsights_occupancy_sample.json` — sample occupancy records

---

### 6. test-credentials.ps1

**Purpose**: Verify the VEA credential system end to end.

**Usage**:
```powershell
.\test-credentials.ps1            # Six checks, pass/fail summary
.\test-credentials.ps1 -Detailed  # Also prints Client ID and secret length
```

Checks: credentials exist → can be retrieved → format is valid (UUID client ID,
secret longer than 20 characters) → live API authentication succeeds → parameter
validation works → error-handling framework works. Exits `1` on the first failure.

---

### 7. setup-automated.ps1

**Purpose**: Non-interactive VEA credential setup for scripted or remote installs.

**Usage**:
```powershell
.\setup-automated.ps1 -ClientId "<uuid>" -ClientSecret "<secret>"
.\setup-automated.ps1 -UseEnvironmentVariables   # Store as machine env vars instead
.\setup-automated.ps1 -ResetCredentials          # Clear both stores
```

`setup.bat` calls this script for the VEA half of setup.

---

### 8. Shared Modules

These are dot-sourced by the scripts above, not run directly.

| File | Provides |
|------|----------|
| `VeaCredentialManager.ps1` | `VeaCredentialManager` and `VeaEnvironmentCredentials` classes, `Get-VeaCredentials`, `Initialize-VeaCredentials` |
| `VeaValidator.ps1` | `VeaValidator` class, `Test-VeaApiCredentials`, `Test-VeaDateRange`, `Test-VeaFilePermissions` |
| `VeaExceptions.ps1` | `VeaException` hierarchy, `VeaErrorHandler`, `Invoke-VeaSafe`, `Invoke-VeaRetry` |

---

### 9. VEA-Zone-Extractor-Custom.ps1 — deprecated, does not work

This script prompted for dates and then rewrote `VEA-Zone-Extractor.ps1`'s source
in place to inject them. The regular expression it uses no longer matches the
extractor's current code, so the substitution silently does nothing and the run
falls back to the default date range.

The extractor now accepts dates directly, which makes the whole approach obsolete:

```powershell
.\VEA-Zone-Extractor.ps1 -StartDate "2026-01-01T00:00:00Z" -EndDate "2026-01-31T23:59:59Z"
```

`run_custom_dates.bat` calls this script and is deprecated for the same reason.

---

## Batch Files

| File | Purpose |
|------|---------|
| `setup.bat` | Interactive credential setup for VEA and LibInsights |
| `run_daily_pipeline.bat` | **Production.** Runs daily export then daily import; aborts if the export fails. Schedule this. |
| `run_full_pipeline.bat` | Interactive. Extracts year-to-date, then imports everything. Prompts for confirmation. |
| `run_export.bat` | Interactive. Extraction only, year-to-date. |
| `run_import.bat` | Interactive menu: import all / gate counts / occupancy / dry run. |
| `run_custom_dates.bat` | Deprecated — see section 9. |

> **Known issue:** the file counts `run_export.bat` prints at the end always read
> `0`. Its `Get-ChildItem` globs (`*springshare_import.csv`, `*gate_counts.csv`)
> predate the current file naming convention. Extraction itself is unaffected —
> check `output/csv/` directly.

---

## Data Flow Pipeline

```text
1. VEA-Zone-Extractor.ps1  (via Daily-VEA-Export.ps1 or run_export.bat)
   ↓ Authenticates with VEA API (OAuth 2.0)
   ↓ Lists zones, then queries hourly traffic per zone
   ↓ Filters records client-side by zoneId
   ↓ Writes: output/json/*.json  (raw backup)
   ↓ Writes: output/csv/gate_counts/*.csv and output/csv/occupancy/*.csv

2. LibInsights-Importer.ps1  (via Daily-LibInsights-Import.ps1 or run_import.bat)
   ↓ Authenticates with LibInsights API (OAuth 2.0)
   ↓ Reads CSV files from output/csv/
   ↓ Maps each filename to a LibInsights gate_id
   ↓ POSTs records in batches of 100 to /gate-count/43702/save
   ↓ Reports success/failure counts

3. run_daily_pipeline.bat  (combined, for Task Scheduler)
   ↓ Step 1 then step 2, aborting if step 1 fails
   ↓ Both steps log to logs/
```

---

## Technical Details

### VEA API Zone Architecture
- Each physical sensor corresponds to a logical "zone" in VEA
- Zone data endpoint: `/data/traffic?entityType=zone&zoneId={id}`
- **The API returns records for all zones regardless of the `zoneId` parameter.**
  Per-sensor separation is achieved by client-side filtering on `record.zoneId`.
  Removing that filter would duplicate every zone's data into every CSV.
- Hourly records carry `recordDate_hour_1`, `sumins` (entries), and `sumouts` (exits)

### CSV Format Requirements
- **Encoding**: UTF-8 **without BOM** — written with
  `[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]::new($false))`.
  `Out-File -Encoding UTF8` emits a BOM in PowerShell 5.1 and must not be
  substituted here.
- **Delimiter**: comma
- **Granularity**: hourly, one row per sensor per hour
- **Date format**: `yyyy-MM-dd HH:mm` (e.g. `2026-01-15 08:00`)
- **Gate Count Format**: `date,gate_start` — `gate_start` is entries
- **Occupancy Format**: `date,gate_start,gate_end` — entries and exits

Example:
```csv
date,gate_start,gate_end
2026-01-15 08:00,42,38
2026-01-15 09:00,57,51
```

### File Naming Convention
The scripts automatically apply a friendly naming convention:
- **Gate Count Files**: `Gate Count West Wing Level X [Location].csv`
- **Occupancy Files**: `Occupancy West Wing Level X [Location].csv`
- **JSON Files**: `{OriginalSensorName}_zone_data.json` (spaces become underscores)

**Sensor Mapping**:
- McKay Library Level 1 Main Entrance 1 → West Wing Level 1 East Side
- McKay Library Level 1 New Entrance → West Wing Level 1 West Side
- McKay Library Level 2 Stairs → West Wing Level 2 Stairs
- McKay Library Level 3 Bridge → West Wing Level 3 Bridge
- McKay Library Level 3 Stairs → West Wing Level 3 Stairs

An unrecognized sensor ID falls back to a sanitized version of its VEA name and
will be skipped at import time, since no gate ID maps to it.

### Error Handling
- Custom exception hierarchy in `VeaExceptions.ps1` (`VeaApiException`,
  `VeaAuthenticationException`, `VeaDataException`, `VeaValidationException`,
  `VeaConfigurationException`)
- `Invoke-VeaRetry` wraps transient API calls; `Invoke-VeaSafe` wraps
  fail-fast operations
- Per-zone failures are caught and recorded so one bad sensor doesn't abort the run
- Scripts `exit 1` on fatal errors so batch wrappers can check `%ERRORLEVEL%`

---

## Quick Testing

To verify the system is working end to end:

1. `powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1"`
2. `powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1" -SpecificDate "<a known-busy past date>"`
3. Check `output/csv/gate_counts/` and `output/csv/occupancy/` for fresh timestamps
   and non-zero counts
4. `powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1" -DryRun`
5. Only then run the import for real

For problems, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
