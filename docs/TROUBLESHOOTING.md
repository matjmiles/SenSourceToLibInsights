# Troubleshooting Guide

This guide helps resolve common issues with the VEA to LibInsights data pipeline.

## Start Here

Most failures fall out of one of these three checks. Run them in order.

```powershell
# 1. Are VEA credentials stored and working?
powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1"

# 2. Did extraction produce data?
Get-ChildItem "output\csv\gate_counts","output\csv\occupancy" |
    Select-Object Name, Length, LastWriteTime

# 3. What did the last run actually say?
Get-Content "logs\daily-export-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 40
Get-Content "logs\daily-import-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 40
```

The daily wrappers log every step with a timestamp and severity, so the logs are
usually the fastest path to the cause.

---

## 1. Credential Issues

### "No VEA credentials found"
**Cause**: No credentials in secure storage.
**Solution**:
1. Run `setup.bat` to configure credentials interactively
2. Or use automated setup:
   `.\scripts\setup-automated.ps1 -ClientId "your-id" -ClientSecret "your-secret"`
3. Verify: `.\scripts\test-credentials.ps1`

### "Failed to retrieve VEA credentials"
**Cause**: Credential store corruption, or the file was created by a **different
Windows account**. The credential file is DPAPI-encrypted and only decrypts under
the account that wrote it.

**Solution**:
```powershell
# Test credential retrieval
.\scripts\test-credentials.ps1 -Detailed

# If it fails, reset and reconfigure as the account that will run the pipeline
.\scripts\setup-automated.ps1 -ResetCredentials
```

For a scheduled task running as `SYSTEM` or a service account, use machine
environment variables instead — `Get-VeaCredentials` checks these first:

```powershell
[Environment]::SetEnvironmentVariable("VEA_API_CLIENT_ID", "your-id", "Machine")
[Environment]::SetEnvironmentVariable("VEA_API_CLIENT_SECRET", "your-secret", "Machine")
```

### "Credential format is invalid"
**Cause**: `test-credentials.ps1` enforces that the VEA Client ID is a UUID and the
secret is longer than 20 characters.
**Solution**: Re-enter the credentials — this usually means a truncated paste or a
swapped ID/secret. Confirm the values in the VEA portal.

### "LibInsights credentials not found!"
**Cause**: `scripts\libinsights_credentials.xml` is missing. It is gitignored, so a
fresh clone never has it.
**Solution**:
```powershell
.\scripts\LibInsights-API-Explorer.ps1 -SaveCredentials
```
Or re-run `setup.bat`, which writes the same file.

### Credentials work interactively but not from Task Scheduler
This is almost always the DPAPI per-account issue above. Either:
- Configure the task to run as the same user that ran `setup.bat`, **or**
- Switch VEA to machine environment variables, and re-run `setup.bat` as the
  service account so `libinsights_credentials.xml` is encrypted to it.

---

## 2. PowerShell Execution Issues

### "Execution of scripts is disabled on this system"
**Cause**: PowerShell execution policy restricts script execution.
**Solution**:
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "File cannot be loaded because running scripts is disabled"
**Solution**: Bypass for a single execution — this is what every `.bat` wrapper does:
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1"
```

### "The term '...' is not recognized" for a class or function
**Cause**: A script was run from the wrong directory, or a shared module
(`VeaCredentialManager.ps1`, `VeaValidator.ps1`, `VeaExceptions.ps1`) is missing
from `scripts\`.
**Solution**: Confirm all three modules exist next to the script being run. They
are dot-sourced by path at startup and the script exits `1` if one is absent.

---

## 3. VEA API Issues

### "401 Unauthorized" or "403 Forbidden"
**Causes & Solutions**:

1. **Invalid credentials**:
   ```powershell
   .\scripts\test-credentials.ps1
   ```
2. **Expired credentials**: renew API access with SenSource, then re-run `setup.bat`
3. **Network/proxy issues**:
   ```powershell
   Test-NetConnection -ComputerName "auth.sensourceinc.com" -Port 443
   Test-NetConnection -ComputerName "vea.sensourceinc.com" -Port 443
   ```

### "Token expired" or "Invalid token"
Each script run requests a fresh token, so this normally indicates a clock skew
problem on the server or a very long-running extraction. Check the system time,
then narrow the date range so the run finishes faster.

### "No zones returned from API"
**Causes & Solutions**:
1. **No active sensors** — confirm sensors are online in the VEA dashboard
2. **Permissions** — ensure the API account has access to the zones; contact
   SenSource support to verify
3. **Transient API failure** — `Invoke-VeaRetry` already retries; if it still
   fails, check the VEA status page

### "No data returned for this zone"
This is a warning, not a failure — the run continues with the remaining zones.
**Causes & Solutions**:
1. **No traffic in the window** — expected for closed hours, holidays, and breaks
2. **Date range issues** — dates must be ISO-8601 UTC:
   ```powershell
   $StartDate = "2026-01-01T00:00:00Z"   # Correct
   $EndDate   = "2026-01-31T23:59:59Z"   # Correct
   # NOT "1/1/2026" or "Jan 1, 2026"
   ```
3. **Sensor offline for that period** — check the VEA dashboard for the same dates

---

## 4. CSV Generation Issues

### "No valid hourly records found"
**Cause**: The API responded, but no record carried a usable date field
(`recordDate_hour_1`, `recordDate_day_1`, or `recordDate_month_1`) for that zone.
**Solution**: Inspect the raw response saved alongside the CSV:
```powershell
$raw = Get-Content "output\json\McKay_Library_Level_2_Stairs_zone_data.json" | ConvertFrom-Json
$raw.raw_data.results | Select-Object -First 3 | ConvertTo-Json -Depth 5
```

### CSV files contain data from more than one sensor
**Cause**: The zone filter was removed or broken. The VEA traffic endpoint returns
records for **all** zones even when a `zoneId` is supplied, so both CSV builders
must keep this guard:
```powershell
if ($record.zoneId -ne $ZoneId) { continue }
```

### CSV files are empty or contain only a header
1. Confirm the date range actually contains traffic (see section 3)
2. Check the JSON backup in `output/json/` — if it has results but the CSV doesn't,
   the date-field extraction or zone filter is the problem

### Encoding problems on import
CSVs must be **UTF-8 without BOM**. The extractor writes them with:
```powershell
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
```
Do **not** replace this with `Out-File -Encoding UTF8` — in PowerShell 5.1 that
writes a BOM, which corrupts the first column header. If you have edited a CSV by
hand in Notepad or Excel, re-run the extraction rather than saving over it.

---

## 5. LibInsights Import Issues

### "Authentication failed"
```powershell
# Verify LibInsights credentials and connectivity independently
.\scripts\LibInsights-API-Explorer.ps1 -TestOnly
Test-NetConnection -ComputerName "byui.libinsight.com" -Port 443
```
If auth fails with valid-looking credentials, confirm the API key is still active
in the LibInsights admin console.

### "No CSV files found to import. Run Daily-VEA-Export.ps1 first."
The importer found nothing in `output/csv/`. Run the export step first, or check
that the export actually succeeded in `logs/daily-export-*.log`.

### "Warning: No gate_id mapping found for: <filename>"
**Cause**: The filename doesn't match any pattern in the gate-ID table, so the file
is skipped. This happens when a new sensor is added to VEA, or a file was renamed.
**Solution**: Add the sensor in **both** places — they must stay in sync:
- `$SensorNameMap` and `Get-FriendlyFileName` in `scripts\VEA-Zone-Extractor.ps1`
- `$GateIdMapping` in `scripts\LibInsights-Importer.ps1`

### Batches report FAILED with 400 Bad Request
Common causes, in order of likelihood:
1. **Duplicate records** — the API rejects rows that already exist. This is
   expected on a re-import and is harmless; the data is already in LibInsights.
2. **Both counts zero** — the API rejects `gate_start = 0` and `gate_end = 0`.
   The importer already skips these for occupancy files.
3. **Wrong `gate_id`** — verify against the live configuration:
   ```powershell
   .\scripts\LibInsights-API-Explorer.ps1
   Get-Content "output\json\libinsights_gate_count_libraries.json"
   ```
4. **Malformed date** — must be `yyyy-MM-dd HH:mm`

Isolate the problem with a single record before re-running a full import:
```powershell
.\scripts\LibInsights-Importer.ps1 -TestSingle
```

### Import is slow or intermittently fails
Reduce the batch size so each request is smaller:
```powershell
.\scripts\LibInsights-Importer.ps1 -BatchSize 25
```

### Data imported but doesn't appear in LibInsights
1. Confirm the summary reported a non-zero "Records Imported"
2. Check you're looking at dataset **43702** (SenSource Gate Count By Entrance) —
   both gate counts and occupancy go there
3. Confirm the date range of the LibInsights report covers the imported dates

---

## 6. Scheduled Task Issues

### Task runs but nothing happens
1. Confirm **Start in** is set to the repository root in the task's Action. Without
   it, the relative paths in `run_daily_pipeline.bat` resolve against
   `C:\Windows\System32`.
2. Check whether logs were written at all:
   ```powershell
   Get-ChildItem "logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
   ```
   No log file means the batch file never started — a Task Scheduler
   configuration problem, not a pipeline problem.

### Task reports success but no data was imported
`run_daily_pipeline.bat` returns the exit code of the last step. Read the import
log to see whether records were actually accepted; a run with zero successes still
exits `0` if the API responded.

### "Credentials not found" only under Task Scheduler
See section 1 — this is the DPAPI per-account issue.

See [SERVER-DEPLOYMENT.md](SERVER-DEPLOYMENT.md) for full Task Scheduler setup.

---

## 7. File System Issues

### "Access denied" or "File in use"
1. **Close Excel/text editors** — an open CSV blocks the extractor from rewriting it
2. **Check permissions** — the account running the task needs write access to
   `output\` and `logs\`
3. **Run as Administrator** if the repository lives under `C:\Program Files` or
   another protected path

### "Path not found"
The scripts create their output directories automatically. If this appears, the
working directory is wrong — run from the repository root, or use the `.bat`
wrappers, which `cd /d "%~dp0"` first.

---

## 8. Network and Connectivity Issues

### "Unable to connect to remote server"
```powershell
Test-NetConnection -ComputerName "auth.sensourceinc.com" -Port 443
Test-NetConnection -ComputerName "vea.sensourceinc.com" -Port 443
Test-NetConnection -ComputerName "byui.libinsight.com" -Port 443
```

Behind a corporate proxy:
```powershell
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
```

### TLS errors on older servers
Windows Server 2016 may default to TLS 1.0. Force TLS 1.2 for the session:
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

---

## 9. Performance

### "Script runs very slowly"
The extractor makes one API call per zone, and the response size scales with the
date range. A full year across five zones is a large payload.

1. **Use narrower ranges** — the daily pipeline pulls one day and is fast
2. **Backfill in monthly chunks** rather than a single year-long request:
   ```powershell
   .\scripts\VEA-Zone-Extractor.ps1 -StartDate "2026-01-01T00:00:00Z" -EndDate "2026-01-31T23:59:59Z"
   .\scripts\Daily-LibInsights-Import.ps1
   # then repeat for February, etc.
   ```
   Remember that each extraction overwrites the CSVs — import between chunks.

---

## Debugging Techniques

### Read the logs first
```powershell
# Everything from today's export that wasn't routine INFO
Select-String -Path "logs\daily-export-*.log" -Pattern "\[(ERROR|WARN)\]"
```

### Inspect raw API responses
Every extraction saves the unmodified API response:
```powershell
$raw = Get-Content "output\json\McKay_Library_Level_3_Bridge_zone_data.json" | ConvertFrom-Json
$raw.zone_info                                    # zone id, sensor name, extraction time
$raw.raw_data.results.Count                       # how many records came back
$raw.raw_data.results | Select-Object -First 1 | ConvertTo-Json -Depth 5
```

### Preview an import without sending anything
```powershell
.\scripts\Daily-LibInsights-Import.ps1 -DryRun
```
This prints the record count and a sample payload per file — the fastest way to
confirm gate-ID mapping and date formatting.

### Verbose extraction
```powershell
.\scripts\VEA-Zone-Extractor.ps1 -Verbose
```
The extractor already prints each request URL and per-zone record counts by default.

### Capture a full run to a file
```powershell
.\run_daily_pipeline.bat *> "logs\manual-run.txt"
```

---

## Getting Additional Help

- **VEA/SenSource API issues**: contact SenSource technical support
- **LibInsights issues**: contact Springshare support; the endpoint reference is in
  [LibInsights-API.md](LibInsights-API.md)
- **Script behavior**: see [SCRIPTS.md](SCRIPTS.md); architecture and known
  gotchas are in [CLAUDE.md](../CLAUDE.md)

---

## Known Issues

| Issue | Impact | Workaround |
|-------|--------|------------|
| `VEA-Zone-Extractor-Custom.ps1` silently ignores the dates you enter | Runs with the default year-to-date range instead | Use `-StartDate`/`-EndDate` on `VEA-Zone-Extractor.ps1` |
| `run_custom_dates.bat` wraps the script above | Same as above | Same as above |
| `run_export.bat` prints `0` for both file counts at the end | Cosmetic only; extraction is unaffected | Check `output/csv/` directly |
| `$OccupancyDatasetId = "43600"` is declared but unused | None today — occupancy posts to 43702 with a `gate_end` field | None needed; don't assume 43600 is in use |

---

## Prevention Best Practices

1. **Monitor the logs** — an empty or `ERROR`-heavy `logs/daily-*.log` is the first
   sign of trouble. Failures are silent otherwise.
2. **Dry run before every manual import** — `-DryRun` costs seconds and catches
   mapping and formatting problems before they reach LibInsights.
3. **Test credentials after any password or account change** — especially after
   Windows account changes on the server, which break DPAPI-encrypted stores.
4. **Backfill in chunks and import between them** — extractions overwrite the CSVs.
5. **Keep the two mapping tables in sync** — adding a sensor requires edits in both
   `VEA-Zone-Extractor.ps1` and `LibInsights-Importer.ps1`.
