# PowerShell Guide for VEA-Springshare Scripts

This guides explains the PowerShell commands and concepts used in the VEA to Springshare data pipeline scripts. It's designed for users who may not be familiar with PowerShell scripting.

## Table of Contents
- [PowerShell Basics](#powershell-basics)
- [Script Structure Overview](#script-structure-overview)
- [VEA-Zone-Extractor.ps1 Explained](#vea-zone-extractorps1-explained)
- [LibInsights-Importer.ps1 Explained](#libinsights-importerps1-explained)
- [The Daily Wrapper Scripts Explained](#the-daily-wrapper-scripts-explained)
- [Shared Error Handling](#shared-error-handling)
- [Common PowerShell Commands Reference](#common-powershell-commands-reference)

> **Note:** The code samples below are simplified for teaching. For exact current
> behavior, read the scripts themselves or [SCRIPTS.md](SCRIPTS.md).

## PowerShell Basics

### What is PowerShell?
PowerShell is a command-line shell and scripting language built on .NET. It's designed for system administration and automation tasks.

### Key Concepts
- **Variables**: Start with `$` (e.g., `$ClientId`)
- **Objects**: Everything in PowerShell is an object with properties and methods
- **Pipelines**: Use `|` to pass data between commands
- **Functions**: Reusable blocks of code that perform specific tasks
- **Parameters**: Input values passed to functions or scripts

---

## Script Structure Overview

Every script in this project follows the same pattern:

```powershell
# 1. Parameters (inputs)
param(
    [string]$StartDate = "default-value"
)

# 2. Configuration/Variables
$ApiUrl = "https://api.example.com"

# 3. Functions (reusable code blocks)
function Get-Data { ... }

# 4. Main execution logic
Write-Host "Starting process..."
```

---

## VEA-Zone-Extractor.ps1 Explained

This script extracts sensor data from the VEA API and saves it as JSON files.

### Parameters Section
```powershell
param(
    [string]$DataType = "traffic",
    [string]$DateGrouping = "hour",
    [string]$GateMethod = "Bidirectional",
    [string]$StartDate = "",
    [string]$EndDate = ""
)
```
**Explanation:**
- `param()` defines input parameters users can provide
- `[string]` specifies the data type (text)
- `= "value"` sets default values if the user doesn't specify one
- These allow customization without editing the script
- `$StartDate` and `$EndDate` default to empty strings, which is the script's
  signal to calculate a date range itself (see below)

### Secure Credential Loading
```powershell
$credentials = Get-VeaCredentials
$ClientId = $credentials.ClientId
$ClientSecret = $credentials.ClientSecret
```
**Explanation:**
- `Get-VeaCredentials` retrieves credentials from secure storage
- Uses Windows Credential Manager (encrypted) or environment variables
- Replaces plain text configuration files for better security
- Returns hashtable with `ClientId` and `ClientSecret` properties

### Date Range Defaulting
```powershell
if ([string]::IsNullOrWhiteSpace($StartDate) -or [string]::IsNullOrWhiteSpace($EndDate)) {
    $dateRange = Get-AutomaticDateRange
    $StartDate = $dateRange.StartDate
    $EndDate = $dateRange.EndDate
    $DateRangeMode = "Automatic: Current Year"
} else {
    $DateRangeMode = "Custom"
}
```
**Explanation:**
- `[string]::IsNullOrWhiteSpace()` is a .NET method — PowerShell can call .NET
  directly using `[TypeName]::MethodName()`
- `-or` means either condition triggers the branch
- If the caller supplied no dates, `Get-AutomaticDateRange` returns January 1 of the
  current year through the end of today
- `$DateRangeMode` is only used for the summary printed at the end

Inside `Get-AutomaticDateRange`, dates are built explicitly in UTC:
```powershell
$startOfYear = [DateTime]::new($currentDate.Year, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
$startDate = $startOfYear.ToString("yyyy-MM-ddTHH:mm:ssZ")
```
**Explanation:**
- `[DateTime]::new(...)` constructs a date; `[DateTimeKind]::Utc` marks it as UTC
- `.ToString("yyyy-MM-ddTHH:mm:ssZ")` formats it as ISO-8601, which is what the
  VEA API requires (`2026-01-01T00:00:00Z`)

### Display Information
```powershell
Write-Host "VEA Zone-Based Individual Sensor Extractor" -ForegroundColor Green
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor Cyan
```
**Explanation:**
- `Write-Host` displays colored text to the user
- `-ForegroundColor` sets the text color
- Variables like `$StartDate` are automatically expanded in strings

### Authentication Function
```powershell
function Get-VEAAccessToken {
    param(
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    $Body = @{
        grant_type = "client_credentials"
        client_id = $ClientId
        client_secret = $ClientSecret
    }
    
    try {
        $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $Body
        return $Response.access_token
    }
    catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}
```
**Explanation:**
- `function` defines reusable code blocks
- `@{}` creates a hashtable (key-value pairs)
- `Invoke-RestMethod` makes HTTP API calls
- `-Method Post` specifies HTTP POST request
- `-Body` sends data to the API
- `try/catch` handles errors gracefully
- `$_.Exception.Message` gets error details
- `return` sends data back to the caller

### Zone Retrieval
```powershell
function Get-VEAZones {
    param([string]$AccessToken)
    
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }
    
    $Response = Invoke-RestMethod -Uri "$ApiBaseUrl/zone" -Method Get -Headers $Headers
    return $Response
}
```
**Explanation:**
- `$Headers` creates HTTP headers for authentication
- `"Bearer $AccessToken"` follows OAuth 2.0 standard
- `-Headers` sends authentication with the request
- `-Method Get` retrieves data (doesn't change anything)

### Data Processing Loop
```powershell
foreach ($zone in $zones) {
    $sensorName = $SensorNameMap[$zone.sensorId]
    if (-not $sensorName) {
        $sensorName = "Unknown Sensor $($zone.sensorId)"
    }
    Write-Host "   Zone ID: $($zone.zoneId)" -ForegroundColor Gray
}
```
**Explanation:**
- `foreach` loops through each item in a collection
- `$zone` is the current item being processed
- `.sensorId` accesses a property of the zone object
- `$SensorNameMap[$zone.sensorId]` looks up friendly names in a hashtable
- `if (-not ...)` provides a fallback when the lookup finds nothing
- `$()` allows complex expressions inside strings

### Client-Side Zone Filtering
```powershell
foreach ($record in $ZoneData.results) {
    if ($record.zoneId -ne $ZoneId) {
        continue  # Skip records from other zones
    }
    # ...build a CSV row...
}
```
**Explanation:**
- `-ne` means "not equal"
- `continue` skips to the next loop iteration without running the rest of the body
- **This filter is essential.** The VEA API returns records for every zone even
  when the request specifies a single `zoneId`. Without this check, every sensor's
  CSV would contain every other sensor's data.

### Writing CSV Without a Byte Order Mark
```powershell
$CsvContent = $CsvLines -join "`n"
[System.IO.File]::WriteAllText($CsvFile, $CsvContent, [System.Text.UTF8Encoding]::new($false))
```
**Explanation:**
- `-join "`n"` joins an array of strings into one string separated by newlines
- `[System.IO.File]::WriteAllText()` is a .NET method that gives exact control
  over encoding
- `[System.Text.UTF8Encoding]::new($false)` means "UTF-8, **no** byte order mark"
- This matters: PowerShell 5.1's `Out-File -Encoding UTF8` writes a BOM, which
  LibInsights reads as part of the first column header and rejects. Do not
  substitute the simpler-looking cmdlet here.

---

## LibInsights-Importer.ps1 Explained

This script reads the generated CSV files and posts them to the LibInsights API.

### Hashtable Lookup by Pattern
```powershell
$GateIdMapping = @{
    "West Wing Level 1 East Side"  = 12
    "West Wing Level 1 West Side"  = 13
}

function Get-GateIdFromFileName {
    param([string]$FileName)

    foreach ($pattern in $GateIdMapping.Keys) {
        if ($FileName -like "*$pattern*") {
            return $GateIdMapping[$pattern]
        }
    }
    return $null
}
```
**Explanation:**
- `@{}` creates a hashtable mapping text keys to numeric values
- `.Keys` gets all the keys so you can loop over them
- `-like` does wildcard matching (`*` means "any characters"), unlike `-eq` which
  requires an exact match
- Returning `$null` signals "no match", and the caller skips that file

### Reading a CSV Into Objects
```powershell
$csvData = Import-Csv -Path $CsvPath

foreach ($row in $csvData) {
    $gateStart = [int]$row.gate_start
    $record = @{
        gate_id    = $GateId
        date       = $row.date
        gate_start = $gateStart
    }
    $records += $record
}
```
**Explanation:**
- `Import-Csv` reads a CSV and turns each line into an object whose properties are
  named after the column headers — so `$row.gate_start` reads that column
- `[int]` converts text to a whole number (CSV values always arrive as strings)
- `+=` on an array creates a new array with the item appended

### Sending Data to the API
```powershell
$headers = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type"  = "application/json"
}
$body = $Records | ConvertTo-Json -Depth 10

if ($Records.Count -eq 1) {
    $body = "[$body]"
}

$response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
```
**Explanation:**
- `ConvertTo-Json` converts PowerShell objects into JSON text
- `-Depth 10` controls how many levels of nesting are converted; the default of 2
  silently truncates deeper structures
- The `if` handles a PowerShell quirk: converting a **single-item** array produces
  a bare object rather than an array, so the brackets are added back manually. The
  API requires an array either way.

### Processing in Batches
```powershell
for ($i = 0; $i -lt $totalRecords; $i += $BatchSize) {
    $endIndex = [math]::Min($i + $BatchSize - 1, $totalRecords - 1)
    $batch = $Records[$i..$endIndex]

    # ...send $batch...

    Start-Sleep -Milliseconds 200
}
```
**Explanation:**
- `$i += $BatchSize` advances by a whole batch each iteration instead of one record
- `[math]::Min()` prevents the last batch from running past the end of the array
- `$Records[$i..$endIndex]` is a **range slice** — `..` builds a sequence of indexes
- `Start-Sleep -Milliseconds 200` pauses between requests to avoid rate limiting

---

## The Daily Wrapper Scripts Explained

`Daily-VEA-Export.ps1` and `Daily-LibInsights-Import.ps1` don't do the work
themselves — they add date handling and logging around the core scripts, so
Task Scheduler runs leave a trail.

### Finding the Project Root
```powershell
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$LogDir = Join-Path $ProjectRoot "logs"
```
**Explanation:**
- `$MyInvocation.MyCommand.Path` is the full path of the running script
- `Split-Path -Parent` strips the last segment, giving the containing folder;
  applying it twice walks up from `scripts\` to the repository root
- `Join-Path` combines path segments with the correct separator
- This means the script works no matter what directory it is launched from —
  important, because Task Scheduler may start it anywhere

### The Logging Function
```powershell
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry

    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        default   { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}
```
**Explanation:**
- `[string]$Level = "INFO"` gives the parameter a default, so most calls pass only a message
- `Add-Content` appends a line to a file (unlike `Set-Content`, which overwrites)
- `switch` picks a value from several options; `default` is the fallback
- Assigning a `switch` to a variable captures whatever the matching branch produced
- Every message goes to **both** the log file and the console

### Calculating Yesterday's Date
```powershell
$targetDate = (Get-Date).AddDays(-$DaysBack).Date
$StartDate = $targetDate.ToString("yyyy-MM-ddT00:00:00Z")
$EndDate = $targetDate.ToString("yyyy-MM-ddT23:59:59Z")
```
**Explanation:**
- `.AddDays(-1)` subtracts a day; negative numbers go backward
- `.Date` drops the time component, leaving midnight
- The two `ToString` calls build a full-day window for the API

### Calling Another Script With Splatting
```powershell
$extractorParams = @{
    StartDate = $StartDate
    EndDate = $EndDate
}
& $extractorScript @extractorParams
```
**Explanation:**
- `&` is the **call operator** — it runs a command whose name is in a variable
- `@extractorParams` is **splatting**: the hashtable is expanded into named
  parameters, equivalent to `-StartDate "..." -EndDate "..."`
- Note the `@` instead of `$` — that is what triggers splatting
- Splatting makes optional parameters easy to build conditionally:
  ```powershell
  $importerParams = @{}
  if ($DryRun) { $importerParams.DryRun = $true }
  ```

### Checking Whether the Called Script Failed
```powershell
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
    Write-Log "Exited with code: $LASTEXITCODE" "ERROR"
    exit 1
}
```
**Explanation:**
- `$LASTEXITCODE` is an automatic variable holding the last command's exit code
- It can be `$null` if nothing has set it yet, hence the second check
- `exit 1` ends the script with a failure code, which `run_daily_pipeline.bat`
  reads as `%ERRORLEVEL%` to decide whether to abort the pipeline

---

## Shared Error Handling

Three files in `scripts\` are libraries rather than runnable scripts. They are
loaded with **dot-sourcing**, which runs a file in the *current* scope so its
functions and classes stay available afterward:

```powershell
$modules = @("VeaCredentialManager.ps1", "VeaValidator.ps1", "VeaExceptions.ps1")

foreach ($module in $modules) {
    $modulePath = Join-Path $PSScriptRoot $module
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}
```
**Explanation:**
- `. $modulePath` — the leading dot is the **dot-source operator**. Running
  `& $modulePath` instead would execute the file in its own scope and the
  definitions would vanish.
- `$PSScriptRoot` is the folder containing the running script
- `Test-Path` checks for existence before use, so a missing file gives a clear
  message instead of a confusing "command not found" later

`VeaExceptions.ps1` provides two wrappers used throughout the extractor:

```powershell
# Retry transient failures (network blips, brief API outages)
$response = Invoke-VeaRetry { Invoke-RestMethod -Uri $dataUrl -Headers $headers }

# Run once, with consistent error reporting on failure
$accessToken = Invoke-VeaSafe { Get-VEAAccessToken } "authentication"
```
**Explanation:**
- `{ ... }` here is a **script block** — a chunk of code passed as a value and run
  later by the receiving function
- `Invoke-VeaRetry` re-runs the block if it throws, which suits network calls
- `Invoke-VeaSafe` takes a description used in the error message, which suits
  operations where retrying wouldn't help

Ordinary `try`/`catch` handles per-zone failures so one bad sensor doesn't end the run:

```powershell
try {
    $zoneData = Get-ZoneTrafficData -AccessToken $accessToken -ZoneId $zone.zoneId
}
catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
```
**Explanation:**
- `try` contains code that might fail; `catch` runs only when it does
- `$_` is the current error object inside a `catch`
- `$_.Exception.Message` is the human-readable reason
- Catching inside the loop means the `foreach` continues with the next zone

---

## Common PowerShell Commands Reference

### Variables and Data Types
```powershell
$text = "Hello World"          # String (text)
$number = 42                   # Integer (whole number)
$date = Get-Date               # DateTime object
$array = @("item1", "item2")   # Array (list)
$hash = @{ key = "value" }     # Hashtable (key-value pairs)
```

### Conditional Logic
```powershell
if ($condition) {
    # Do something
} elseif ($other) {
    # Do something else  
} else {
    # Default action
}
```

### Loops
```powershell
# Loop through collection
foreach ($item in $collection) {
    # Process each item
}

# Loop with counter
for ($i = 0; $i -lt 10; $i++) {
    # Repeat 10 times
}
```

### File Operations
```powershell
Test-Path "file.txt"           # Check if file exists
Get-Content "file.txt"         # Read file contents
"text" | Out-File "file.txt"   # Write text to file
Get-ChildItem "*.json"         # List files matching pattern
```

### Text Operations
```powershell
$text = "Hello World"
$text.Length                   # Get text length
$text.ToUpper()               # Convert to uppercase
$text -replace "Hello", "Hi"   # Replace text
$text -match "World"          # Test if text contains pattern
```

### Object Operations
```powershell
$obj.PropertyName             # Access object property
$obj.MethodName()             # Call object method
$collection | Where-Object { $_.Property -eq "value" }    # Filter
$collection | ForEach-Object { $_.Property }              # Transform
$collection | Sort-Object PropertyName                     # Sort
```

### HTTP/Web Operations
```powershell
Invoke-RestMethod -Uri "https://api.example.com" -Method Get
Invoke-RestMethod -Uri $url -Method Post -Body $data -Headers $headers
```

### Error Handling
```powershell
try {
    # Code that might fail
    $result = Invoke-RestMethod -Uri $url
} catch {
    # Handle errors
    Write-Error "Failed: $($_.Exception.Message)"
} finally {
    # Always runs (cleanup)
    Write-Host "Done"
}
```

### Output and Display
```powershell
Write-Host "Colored text" -ForegroundColor Red     # Display colored text
Write-Output "Data"                                # Send data to pipeline
Write-Error "Error message"                        # Display error
Write-Verbose "Debug info"                         # Display with -Verbose flag
```

## Tips for Reading PowerShell Scripts

1. **Start with parameters** - Look at `param()` to understand inputs
2. **Find the main logic** - Usually at the bottom of the script
3. **Functions are tools** - They're reusable pieces called by main logic
4. **Follow the pipeline** - Data flows left to right with `|`
5. **Variables start with $** - Easy to spot data storage
6. **Indentation matters** - Shows structure and flow
7. **Comments start with #** - Explain what code does
8. **Objects have properties** - Access with `.PropertyName`

## A Note on PowerShell Versions

These scripts target **Windows PowerShell 5.1**, the version built into Windows.
Newer syntax you may find in online examples will **not** work here:

| Not available in 5.1 | Use instead |
|----------------------|-------------|
| `cmd1 && cmd2` | `cmd1; if ($?) { cmd2 }` |
| `$x ? $a : $b` (ternary) | `if ($x) { $a } else { $b }` |
| `$x ?? $b` (null-coalescing) | `if ($null -eq $x) { $b } else { $x }` |
| `ConvertFrom-Json -AsHashtable` | Work with the returned `PSCustomObject` |
| `Out-File -Encoding utf8NoBOM` | `[System.IO.File]::WriteAllText(...)` |

## Where to Go Next

- [SCRIPTS.md](SCRIPTS.md) — what each script does, its parameters, and its outputs
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — diagnosing failures
- [../CLAUDE.md](../CLAUDE.md) — architecture, key constants, and known gotchas

This guide should help you understand how the pipeline scripts work and what each
PowerShell command accomplishes.
