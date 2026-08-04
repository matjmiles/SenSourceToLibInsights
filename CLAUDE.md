# CLAUDE.md

Guidance for Claude Code (and other AI agents) working in this repository.

## What This Project Is

A Windows/PowerShell data pipeline that pulls hourly foot-traffic data from the
**VEA (SenSource)** sensor API for the BYU–Idaho McKay Library and pushes it into
**Springshare LibInsights** via API.

There is no build step, no package manager, and no test framework. Everything is
plain PowerShell 5.1 scripts driven by `.bat` wrappers. The "tests" are dry runs
against the live APIs.

Repository: <https://github.com/byui-library/SenSourceToLibInsights>

## Architecture

```
VEA API  ──►  VEA-Zone-Extractor.ps1  ──►  output/csv/{gate_counts,occupancy}/*.csv
(OAuth2)                                              │
                                                      ▼
                                    LibInsights-Importer.ps1  ──►  LibInsights API
                                                                    (OAuth2)
```

Two layers:

1. **Core scripts** — `VEA-Zone-Extractor.ps1` and `LibInsights-Importer.ps1` do the
   real work and take explicit parameters.
2. **Daily wrappers** — `Daily-VEA-Export.ps1` and `Daily-LibInsights-Import.ps1`
   add date defaulting (yesterday) and timestamped logging to `logs/`, then invoke
   the core scripts. `run_daily_pipeline.bat` chains both for Task Scheduler.

Supporting modules are dot-sourced, not imported as modules:
`VeaCredentialManager.ps1`, `VeaValidator.ps1`, `VeaExceptions.ps1`.

## Common Commands

```powershell
# One-time credential setup (VEA + LibInsights)
setup.bat

# Nightly production run (this is what Task Scheduler calls)
run_daily_pipeline.bat

# Export yesterday's data
powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1"

# Export a specific date (backfill a missed day)
powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1" -SpecificDate "2026-01-15"

# Export an arbitrary range (ISO-8601, UTC)
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1" `
    -StartDate "2026-01-01T00:00:00Z" -EndDate "2026-01-31T23:59:59Z"

# Import — always dry-run first
powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1" -DryRun
powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1"

# Verify VEA credentials and connectivity
powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1" -Detailed
```

## Verifying Changes

There is no test suite. Verify by:

1. `scripts\test-credentials.ps1` — confirms credential storage and VEA auth.
2. `scripts\Daily-VEA-Export.ps1 -SpecificDate <a known-good past date>` — confirms
   extraction and CSV generation.
3. `scripts\Daily-LibInsights-Import.ps1 -DryRun` — confirms parsing and gate-ID
   mapping without writing to LibInsights.
4. Only then run the import for real. The LibInsights API rejects duplicate
   records, so a repeat import is safe but will report failures for existing rows.

## Key Constants

Changing any of these requires a coordinated change in both scripts.

**Sensor → gate mapping** (`VEA-Zone-Extractor.ps1` maps sensor ID → friendly name;
`LibInsights-Importer.ps1` maps friendly name → gate ID):

| VEA sensor name | CSV / friendly name | LibInsights `gate_id` |
|---|---|---|
| McKay Library Level 1 Main Entrance 1 | West Wing Level 1 East Side | 12 |
| McKay Library Level 1 New Entrance | West Wing Level 1 West Side | 13 |
| McKay Library Level 2 Stairs | West Wing Level 2 Stairs | 14 |
| McKay Library Level 3 Bridge | West Wing Level 3 Bridge | 15 |
| McKay Library Level 3 Stairs | West Wing Level 3 Stairs | 16 |

**Endpoints:**
- VEA auth: `https://auth.sensourceinc.com/oauth/token`
- VEA data: `https://vea.sensourceinc.com/api` (`/zone`, `/data/traffic`)
- LibInsights: `https://byui.libinsight.com/v1.0` (`/oauth/token`, `/gate-count/{id}/save`)

**Dataset IDs:** `43702` = SenSource Gate Count By Entrance. Both gate-count and
occupancy CSVs are posted to `43702`; occupancy rows just carry an extra `gate_end`
field. `$OccupancyDatasetId = "43600"` is declared in the scripts but currently
unused — do not assume occupancy goes to 43600.

## Data Formats

CSVs are **hourly**, not daily. The `date` column is `yyyy-MM-dd HH:mm`.

```csv
# output/csv/gate_counts/*.csv
date,gate_start
2026-01-15 08:00,42

# output/csv/occupancy/*.csv
date,gate_start,gate_end
2026-01-15 08:00,42,38
```

`gate_start` = entries (`sumins`), `gate_end` = exits (`sumouts`).

Files must be **UTF-8 without BOM**. The extractor writes them with
`[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]::new($false))`
specifically for this reason — do not replace that with `Out-File -Encoding UTF8`,
which emits a BOM in PowerShell 5.1.

Rows where both `gate_start` and `gate_end` are 0 are skipped on occupancy import;
the LibInsights API returns 400 for them.

## Credentials

Never write credentials into scripts or docs. The authoritative copy of both
credential sets lives in **LastPass**; everything below is a per-machine artifact
recreated by `setup.bat`. Storage:

- **VEA** — `$env:APPDATA\VEA-API\credentials.xml`, DPAPI-encrypted via
  `Export-Clixml`. Falls back to machine environment variables
  `VEA_API_CLIENT_ID` / `VEA_API_CLIENT_SECRET` (needed when the scheduled task
  runs as SYSTEM, since DPAPI blobs are per-user).
- **LibInsights** — `scripts\libinsights_credentials.xml`, also `Export-Clixml`.
  Gitignored.

Both files are encrypted to the user account that created them. A credential set
written by an interactive user will not decrypt under a different service account.

## Conventions

- **PowerShell 5.1** (Windows PowerShell). No `&&`/`||` chaining, no ternary, no
  null-coalescing. Use `;` and `if ($?) { }`.
- 4-space indent. `$camelCase` locals, `PascalCase` functions, `Verb-Noun` naming.
- Paths are Windows-style with backslashes; scripts resolve `$ProjectRoot` from
  `$PSScriptRoot`/`$MyInvocation` rather than assuming the working directory.
- Status output uses `Write-Host -ForegroundColor`. The daily wrappers additionally
  write to `logs/daily-{export,import}-yyyy-MM-dd.log` via their `Write-Log` helper.
- Errors use `try`/`catch` with the custom exception types in `VeaExceptions.ps1`
  (`VeaApiException`, `VeaAuthenticationException`, `VeaDataException`,
  `VeaValidationException`) and the `Invoke-VeaSafe` / `Invoke-VeaRetry` helpers.
- Scripts `exit 1` on failure so batch wrappers can check `%ERRORLEVEL%`.

## Gotchas

- **The VEA traffic endpoint returns records for all zones** even when queried with
  `zoneId`. Both CSV builders filter with `if ($record.zoneId -ne $ZoneId) { continue }`.
  Removing that filter silently duplicates every zone's data into every file.
- **`output/csv/*.csv` is in `.gitignore` but the files are already tracked**, so
  edits still show up in `git status`. They are committed baseline data. Don't sweep
  daily data churn into unrelated commits.
- **`VEA-Zone-Extractor-Custom.ps1` is deprecated and does not work.** It tries to
  rewrite the extractor's source with a regex that no longer matches, so it silently
  falls back to the default date range. Use `-StartDate`/`-EndDate` on
  `VEA-Zone-Extractor.ps1` instead.
- **`run_export.bat`'s trailing file counts print 0.** Its `Get-ChildItem` globs
  (`*springshare_import.csv`, `*gate_counts.csv`) predate the current file naming.
  The extraction itself is unaffected.
- `archive/` holds superseded exploration scripts from initial development. Don't
  treat anything there as current; `docs/archive/` is the same idea for docs.

## Documentation Map

- [README.md](README.md) — overview and quick start
- [docs/SERVER-DEPLOYMENT.md](docs/SERVER-DEPLOYMENT.md) — production install and Task Scheduler
- [docs/SCRIPTS.md](docs/SCRIPTS.md) — per-script reference
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — failure modes and fixes
- [docs/LibInsights-API.md](docs/LibInsights-API.md) — LibInsights endpoint reference
- [docs/POWERSHELL_GUIDE.md](docs/POWERSHELL_GUIDE.md) — PowerShell primer for maintainers
