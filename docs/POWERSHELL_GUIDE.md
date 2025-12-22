# PowerShell Guide for VEA-Springshare Scripts

This guides explains the PowerShell commands and concepts used in the VEA to Springshare data pipeline scripts. It's designed for users who may not be familiar with PowerShell scripting.

## Table of Contents
- [PowerShell Basics](#powershell-basics)
- [Script Structure Overview](#script-structure-overview)
- [VEA-Zone-Extractor.ps1 Explained](#vea-zone-extractorps1-explained)
- [VEA-Zone-CSV-Processor.ps1 Explained](#vea-zone-csv-processorps1-explained)
- [VEA-Generate-All-Individual-CSVs.ps1 Explained](#vea-generate-all-individual-csvs)
- [Common PowerShell Commands Reference](#common-powershell-commands-reference)

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

All three scripts follow a similar pattern:

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
    [string]$StartDate = "2025-12-01T00:00:00Z",
    [string]$EndDate = "2025-12-08T23:59:59Z",
    [string]$DataType = "traffic",
    [string]$DateGrouping = "hour",
    [string]$GateMethod = "Bidirectional"
)
```
**Explanation:**
- `param()` defines input parameters users can provide
- `[string]` specifies the data type (text)
- `= "value"` sets default values if user doesn't specify
- These allow customization without editing the script

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

### Date Format Handling
```powershell
if ($StartDate -notmatch 'T.*Z$') {
    $StartDate = "${StartDate}T00:00:00Z"
}
```
**Explanation:**
- `-notmatch` checks if text doesn't match a pattern
- `'T.*Z$'` is a regular expression pattern for ISO-8601 format
- `${}` allows variable substitution within strings
- Converts simple dates like "2025-12-01" to full format "2025-12-01T00:00:00Z"

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
    $sensorId = $zone.deviceId
    $sensorName = $SensorNameMap[$sensorId]
    
    if ($sensorName) {
        Write-Host "Processing Zone:" -ForegroundColor Yellow
        Write-Host "   Zone ID: $($zone.zoneId)" -ForegroundColor Gray
    }
}
```
**Explanation:**
- `foreach` loops through each item in a collection
- `$zone` is the current item being processed
- `.deviceId` accesses a property of the zone object
- `$SensorNameMap[$sensorId]` looks up friendly names in a hashtable
- `if` statements execute code only when conditions are true
- `$()` allows complex expressions inside strings

### Error Handling
```powershell
try {
    $ZoneData = Get-ZoneTrafficData -AccessToken $AccessToken
}
catch {
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    return $null
}
```
**Explanation:**
- `try` block contains code that might fail
- `catch` block runs only if an error occurs
- `$_` represents the current error object
- Prevents script from crashing on API failures

---

## VEA-Zone-CSV-Processor.ps1 Explained

This script converts JSON zone data into Springshare-compatible CSV files.

### Object Creation
```powershell
$ZoneRecords = $AllRecords | Where-Object { $_.zoneId -eq $TargetZoneId }
```
**Explanation:**
- `|` (pipe) passes data from left side to right side
- `Where-Object` filters data based on conditions
- `{ }` contains the filtering logic
- `$_.zoneId` accesses the zoneId property of each record
- `-eq` means "equals" (comparison operator)
- Result contains only records matching the target zone

### Data Grouping
```powershell
$DailyData = $ZoneRecords | Group-Object { 
    [DateTime]::Parse($_.timestamp).Date.ToString("yyyy-MM-dd") 
}
```
**Explanation:**
- `Group-Object` organizes data by common values
- `[DateTime]::Parse()` converts text to date objects
- `.Date` gets just the date part (removes time)
- `.ToString("yyyy-MM-dd")` formats date as "2025-12-01"
- Groups all records by the same date

### Calculation Logic
```powershell
$TotalEntries = ($DayGroup.Group | Measure-Object -Property entries -Sum).Sum
$TotalExits = ($DayGroup.Group | Measure-Object -Property exits -Sum).Sum
```
**Explanation:**
- `$DayGroup.Group` gets all records for a specific day
- `Measure-Object` performs calculations on collections
- `-Property entries` specifies which field to calculate
- `-Sum` adds up all the values
- `.Sum` gets the final total

### CSV Creation
```powershell
$CsvData = $DailyTotals.GetEnumerator() | Sort-Object Key | ForEach-Object {
    [PSCustomObject]@{
        date = $_.Key
        gate_start = $_.Value.Entries
        gate_end = $_.Value.Exits
    }
}
```
**Explanation:**
- `.GetEnumerator()` allows looping through hashtable entries
- `Sort-Object Key` sorts by date
- `ForEach-Object` transforms each item
- `[PSCustomObject]@{}` creates structured data objects
- Creates objects with exact column names Springshare expects

### File Output
```powershell
$CsvData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
```
**Explanation:**
- `Export-Csv` converts objects to CSV format and saves to file
- `-NoTypeInformation` prevents extra header row
- `-Encoding UTF8` ensures proper text encoding for Springshare

---

## VEA-Generate-All-Individual-CSVs.ps1 Explained

This script processes multiple zone files in batch mode.

### File Discovery
```powershell
$ZoneFiles = Get-ChildItem -Path "." -Filter "*_zone_data.json"
```
**Explanation:**
- `Get-ChildItem` lists files and folders (like `dir` or `ls`)
- `-Path "."` means current directory
- `-Filter` limits results to files matching the pattern
- `*` is a wildcard meaning "any characters"

### Progress Tracking
```powershell
$Counter = 0
$TotalFiles = $ZoneFiles.Count
Write-Host "Found $TotalFiles zone JSON files to process" -ForegroundColor Cyan
```
**Explanation:**
- Variables store numbers and text
- `.Count` gets the number of items in a collection
- String interpolation automatically converts numbers to text

### File Processing Loop
```powershell
foreach ($file in $ZoneFiles) {
    $Counter++
    Write-Host "[$Counter/$TotalFiles] Processing: $($file.Name)" -ForegroundColor Yellow
    
    $JsonData = Get-Content $file.FullName | ConvertFrom-Json
}
```
**Explanation:**
- `$Counter++` increases counter by 1
- `$file.Name` gets just the filename
- `$file.FullName` gets the complete path
- `Get-Content` reads entire file as text
- `ConvertFrom-Json` converts JSON text to PowerShell objects

### Data Validation
```powershell
if (-not $JsonData -or $JsonData.Count -eq 0) {
    Write-Host "  Warning: No data in file" -ForegroundColor Yellow
    continue
}
```
**Explanation:**
- `-not` means "not" or "false"
- `-or` means "or" (either condition can be true)
- `-eq 0` checks if count equals zero
- `continue` skips to next iteration of loop

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

This guide should help you understand how the VEA-Springshare scripts work and what each PowerShell command accomplishes!