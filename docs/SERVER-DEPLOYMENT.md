# Server Deployment Guide

Complete guide for deploying the VEA to LibInsights pipeline on a Windows Server with Task Scheduler automation.

## Prerequisites

- Windows Server 2016+ (or Windows 10/11)
- PowerShell 5.1 or higher
- Administrator access for Task Scheduler
- Outbound HTTPS (443) to:
  - `auth.sensourceinc.com` — VEA authentication
  - `vea.sensourceinc.com` — VEA data
  - `byui.libinsight.com` — LibInsights
- API Credentials (from LastPass — see below):
  - VEA: Client ID (UUID) and Secret
  - LibInsights: Client ID and Secret

### Where to Get the Credentials

Both the VEA and LibInsights credentials are stored in **LastPass**. Retrieve all
four values from the library's LastPass vault before starting — `setup.bat` will
prompt for each of them. They are not stored anywhere in this repository, and the
encrypted files the scripts create cannot be copied between machines (see below).

> **Decide up front which account will run the scheduled task.** Credentials are
> encrypted per Windows account, so setup must be run as that same account — or
> VEA credentials must be stored as machine environment variables instead. See
> [Credentials Not Found](#credentials-not-found).

---

## Step 1: Deploy the Code

```powershell
# Navigate to desired location
cd C:\Scripts

# Clone the repository
git clone https://github.com/byui-library/SenSourceToLibInsights.git
cd SenSourceToLibInsights
```

Or copy the project folder from your development machine.

---

## Step 2: Configure All Credentials

Have the **LastPass** entries open before you start — you will need all four values.

Run the setup script to configure **both** VEA and LibInsights credentials:

```batch
setup.bat
```

This will prompt you for:
1. **VEA API Client ID** (UUID format)
2. **VEA API Client Secret**
3. **LibInsights Client ID**
4. **LibInsights Client Secret**

Credentials are then stored securely on this machine:
- VEA: DPAPI-encrypted file at `%APPDATA%\VEA-API\credentials.xml`
- LibInsights: DPAPI-encrypted file at `scripts\libinsights_credentials.xml`

Both files are encrypted to the Windows account that created them, so they cannot
be copied to another machine or reused under a different account. On a new server,
always re-run `setup.bat` with the values from LastPass rather than copying files
across.

Verify before moving on:

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1"
```

---

## Step 3: Test the Pipeline

### Test Export (Previous Day)
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\Daily-VEA-Export.ps1"
```

Confirm CSVs were written before continuing:

```powershell
Get-ChildItem "output\csv\gate_counts","output\csv\occupancy" |
    Select-Object Name, Length, LastWriteTime
```

### Test Import (Dry Run)
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\Daily-LibInsights-Import.ps1" -DryRun
```

This sends nothing. Check that each file reports a sensible record count and a
sample payload with the correct `gate_id`.

### Test Full Pipeline
```batch
run_daily_pipeline.bat
```

This one **does** write to LibInsights. Verify the data lands in dataset 43702
before creating the scheduled task.

---

## Step 4: Create the Scheduled Task

### Using Task Scheduler GUI

1. **Open Task Scheduler**: `Win + R` → `taskschd.msc`

2. **Create Task** (not "Basic Task") → Right-click → "Create Task..."

3. **General Tab**:
   - Name: `VEA to LibInsights Daily Pipeline`
   - ☑ Run whether user is logged on or not
   - ☑ Run with highest privileges

4. **Triggers Tab** → New:
   - Daily at `2:00:00 AM`
   - ☑ Enabled

5. **Actions Tab** → New:
   - Program/script: `C:\Scripts\SenSourceToLibInsights\run_daily_pipeline.bat`
   - Start in: `C:\Scripts\SenSourceToLibInsights`

6. **Conditions Tab**:
   - ☑ Start only if network connection is available

7. **Settings Tab**:
   - ☑ Allow task to be run on demand
   - ☑ If task fails, restart every 30 minutes (up to 3 times)

8. **Save** → Enter Windows password when prompted

### Using PowerShell (Administrator)

```powershell
$TaskPath = "C:\Scripts\SenSourceToLibInsights"

Register-ScheduledTask `
    -TaskName "VEA to LibInsights Daily Pipeline" `
    -Action (New-ScheduledTaskAction -Execute "$TaskPath\run_daily_pipeline.bat" -WorkingDirectory $TaskPath) `
    -Trigger (New-ScheduledTaskTrigger -Daily -At "02:00") `
    -Principal (New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest) `
    -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 30)) `
    -Description "Extracts previous day's VEA sensor data and imports to LibInsights"
```

---

## Step 5: Verify Setup

### Check Task Exists
```powershell
Get-ScheduledTask -TaskName "VEA to LibInsights Daily Pipeline"
```

### Run Manually
```powershell
Start-ScheduledTask -TaskName "VEA to LibInsights Daily Pipeline"
```

### Check Logs
```powershell
# Today's export log
Get-Content "logs\daily-export-$(Get-Date -Format 'yyyy-MM-dd').log"

# Today's import log  
Get-Content "logs\daily-import-$(Get-Date -Format 'yyyy-MM-dd').log"
```

---

## Troubleshooting

### Credentials Not Found

Both credential stores are encrypted with DPAPI, which ties them to the Windows
account that created them. A credential set saved by an interactive admin will
**not** decrypt when the task runs as `SYSTEM` or a service account.

Either fix below means re-entering the credentials, so have the **LastPass**
entries to hand. Copying the encrypted files from a working machine will not work.

Pick one of these:

**Option A — run the task as the account that ran setup.** Simplest, but the
password must be maintained in Task Scheduler.

**Option B — use machine environment variables for VEA.** `Get-VeaCredentials`
checks these before the encrypted file, so they take precedence:
```powershell
[Environment]::SetEnvironmentVariable("VEA_API_CLIENT_ID", "your-id", "Machine")
[Environment]::SetEnvironmentVariable("VEA_API_CLIENT_SECRET", "your-secret", "Machine")
```
LibInsights has no environment-variable fallback, so `libinsights_credentials.xml`
still has to be written by the account that runs the task. Use `psexec -s` or a
scheduled one-off task to run `setup.bat` as that account.

Verify from the target account:
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1"
```

### Task Runs but Produces No Logs

The `logs/` directory is created on first run. If it stays empty, the batch file
never executed — check that **Start in** is set to the repository root in the
task's Action tab. Without it, relative paths resolve against `C:\Windows\System32`.

### Network Errors
Check the firewall allows outbound HTTPS (443) to:
- `auth.sensourceinc.com`
- `vea.sensourceinc.com`
- `byui.libinsight.com`

On Windows Server 2016, TLS 1.0 may be the default and will fail against these
APIs. Verify TLS 1.2 is enabled system-wide.

### Manual Recovery
If a day was missed:
```powershell
# Export specific date
.\scripts\Daily-VEA-Export.ps1 -SpecificDate "2026-01-15"

# Import to LibInsights
.\scripts\Daily-LibInsights-Import.ps1
```

For several missed days, repeat this pair per day. Each export overwrites the CSVs,
so the import must run before the next export.

Re-importing a date that already loaded is safe — the API rejects duplicates. Those
rejections are counted as failures in the summary, which is expected in this case.

For anything not covered here, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## What Runs Daily

The `run_daily_pipeline.bat` script:

1. **Extracts** previous day's VEA sensor data (complete 24-hour data)
2. **Generates** CSV files in `output/csv/`
3. **Imports** to LibInsights via API
4. **Logs** results to `logs/` directory

Schedule it to run after midnight (e.g., 2:00 AM) to ensure yesterday's data is complete.

If the export step fails, the pipeline aborts before importing — it will not push
partial data.

---

## Ongoing Maintenance

### Log Retention

Logs are written one file per day and are never pruned automatically. Add a monthly
cleanup task if disk space matters:

```powershell
Get-ChildItem "C:\Scripts\SenSourceToLibInsights\logs" -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } |
    Remove-Item
```

### Monitoring

A silent failure looks identical to a silent success unless you check. Weekly:

```powershell
# Any errors or warnings in the last week's logs?
Get-ChildItem "logs\*.log" |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
    Select-String -Pattern "\[(ERROR|WARN)\]"

# Did the task actually run last night?
Get-ScheduledTaskInfo -TaskName "VEA to LibInsights Daily Pipeline" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

`LastTaskResult` of `0` means the batch file exited cleanly. It does **not**
guarantee records were accepted — confirm against the import log.

### Updating the Deployment

```powershell
cd C:\Scripts\SenSourceToLibInsights
git pull
```

Credentials live outside the repository (`%APPDATA%` and the gitignored
`libinsights_credentials.xml`), so a pull does not disturb them.

---

## Security

- **System of record**: both credential sets live in **LastPass**. Treat that as
  the authoritative copy — the files below are per-machine artifacts that can be
  recreated at any time by re-running `setup.bat`.
- **VEA credentials**: DPAPI-encrypted at `%APPDATA%\VEA-API\credentials.xml`,
  or machine environment variables for service accounts
- **LibInsights credentials**: DPAPI-encrypted XML at
  `scripts\libinsights_credentials.xml` (gitignored)
- **All API calls**: HTTPS only
- **No plain text secrets** in repository

Restrict filesystem permissions on the deployment directory to the service account
and administrators — the encrypted credential file is only as safe as the account
it is bound to.
