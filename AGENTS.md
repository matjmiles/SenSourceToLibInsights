# Agent Guidelines for the VEA → LibInsights Repository

**The canonical guide is [CLAUDE.md](CLAUDE.md).** Read it first — it covers
architecture, key constants, data formats, and known gotchas. This file is a
condensed command and style reference kept in sync with it.

## Commands

There is no build system, package manager, or test framework. Everything is
Windows PowerShell 5.1 driven by `.bat` wrappers.

### Pipeline Execution
- **Daily pipeline (scheduled)**: `run_daily_pipeline.bat` — extracts the previous
  day's data and imports it; for Task Scheduler
- **Full pipeline (manual)**: `run_full_pipeline.bat` — extracts year-to-date and imports
- **Setup all credentials**: `setup.bat` — configures VEA + LibInsights

### PowerShell Scripts
- **Daily export (yesterday)**: `powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1"`
- **Daily export (specific date)**: `powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1" -SpecificDate "2026-01-15"`
- **Daily import**: `powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1"`
- **Daily import (dry run)**: `powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1" -DryRun`
- **Custom date extraction**: `powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1" -StartDate "2026-01-01T00:00:00Z" -EndDate "2026-01-31T23:59:59Z"`

### Credential Management
- **Both credentials**: `setup.bat`
- **VEA automated setup**: `powershell -ExecutionPolicy Bypass -File "scripts\setup-automated.ps1" -ClientId "id" -ClientSecret "secret"`
- **VEA reset**: `powershell -ExecutionPolicy Bypass -File "scripts\setup-automated.ps1" -ResetCredentials`
- **LibInsights only**: `powershell -ExecutionPolicy Bypass -File "scripts\LibInsights-API-Explorer.ps1" -SaveCredentials`

### Verification (no test suite — verify against the live APIs)
1. **Credentials**: `powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1"`
2. **Export**: `powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1"`
3. **Import preview**: `powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1" -DryRun`
4. **Then** run the real import. Never skip the dry run.

## Code Style Guidelines

### PowerShell Conventions
- **Target**: Windows PowerShell 5.1 only. No `&&`/`||` chaining, no ternary, no
  null-coalescing, no `-AsHashtable`. Use `;` and `if ($?) { }`.
- **Variables**: `$camelCase` for locals (e.g., `$accessToken`, `$zoneData`)
- **Functions**: `PascalCase`, `Verb-Noun` (e.g., `Get-VEAAccessToken`)
- **Parameters**: `param()` blocks with `[string]`, `[int]`, `[switch]` type hints
- **Comments**: `#` for single lines explaining non-obvious logic
- **Error Handling**: `try`/`catch` with the custom exception types in
  `VeaExceptions.ps1`; `exit 1` on fatal errors so `.bat` wrappers can check `%ERRORLEVEL%`
- **Indentation**: 4 spaces

### Naming Conventions
- **Files**: PascalCase, descriptive (e.g., `VEA-Zone-Extractor.ps1`)
- **API endpoints**: consistent URL construction from `$ApiBaseUrl`
- **CSV outputs**: `Gate Count {FriendlyName}.csv` / `Occupancy {FriendlyName}.csv`
- **JSON outputs**: `{SensorName}_zone_data.json`
- **Paths**: resolve from `$PSScriptRoot` / `$MyInvocation`, never from the CWD

### Imports and Dependencies
- **Modules**: no external PowerShell modules — built-in cmdlets only
- **Shared code**: dot-sourced by path (`. $modulePath`), not `Import-Module`
- **API calls**: `Invoke-RestMethod`, wrapped in `Invoke-VeaRetry` for transient calls

### Data Handling
- **JSON**: `ConvertFrom-Json` / `ConvertTo-Json -Depth 10` or greater
- **CSV writes**: `[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]::new($false))`.
  **Do not** use `Out-File -Encoding UTF8` — it emits a BOM in PS 5.1, which breaks
  the LibInsights import.
- **Date formats**: ISO-8601 UTC for API calls; `yyyy-MM-dd HH:mm` in CSVs (hourly,
  not daily)
- **Zone filtering**: the VEA traffic endpoint returns all zones regardless of the
  `zoneId` parameter — always keep the `if ($record.zoneId -ne $ZoneId) { continue }` guard

### Logging
- **Status**: `Write-Host -ForegroundColor` for interactive output
- **Daily wrappers**: also append to `logs/daily-{export,import}-yyyy-MM-dd.log`
  via their `Write-Log` helper with `INFO`/`WARN`/`ERROR`/`SUCCESS` levels
- **Progress**: show counters for batch operations

## Cautions

- Never commit credentials. `scripts/libinsights_credentials.xml` is gitignored.
- `output/csv/*.csv` is gitignored but already tracked — don't sweep data churn
  into unrelated commits.
- Changing a sensor requires edits in **both** `VEA-Zone-Extractor.ps1`
  (`$SensorNameMap`, `Get-FriendlyFileName`) and `LibInsights-Importer.ps1`
  (`$GateIdMapping`).
- `VEA-Zone-Extractor-Custom.ps1` and `run_custom_dates.bat` are deprecated and
  silently ignore the dates entered. Use `-StartDate`/`-EndDate` instead.
- `archive/` and `docs/archive/` hold superseded material — reference only.
