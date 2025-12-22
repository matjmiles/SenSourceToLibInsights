# VEA to Springshare LibInsights Data Pipeline

This application extracts individual sensor traffic data from the VEA (Visitor Experience Analytics) API and converts it to CSV format for import into Springshare LibInsights.

## Quick Start

### Step 1: Clone and Setup
```bash
git clone https://github.com/matjmiles/SenSourceToLibInsights.git
cd SenSourceToLibInsights
```

### Step 2: Configure Credentials

#### **Option A: Interactive Setup (Recommended for first-time use)**
```batch
setup.bat
```
This will:
- Prompt you to enter your VEA API credentials
- Store them securely in Windows Credential Manager
- Validate format and test API connectivity

#### **Option B: Automated Setup (For scripts/Task Scheduler)**
```powershell
# Set environment variables (recommended for automation)
.\scripts\setup-automated.ps1 -ClientId "your-client-id" -ClientSecret "your-client-secret" -UseEnvironmentVariables

# Or use Windows Credential Manager programmatically
.\scripts\setup-automated.ps1 -ClientId "your-client-id" -ClientSecret "your-client-secret"
```

#### **Option C: Manual Environment Variables**
```powershell
# Set system environment variables
[Environment]::SetEnvironmentVariable("VEA_API_CLIENT_ID", "your-client-id", "Machine")
[Environment]::SetEnvironmentVariable("VEA_API_CLIENT_SECRET", "your-client-secret", "Machine")
```

**Required VEA API Credentials:**
- Client ID (UUID format)
- Client Secret

**Security Note:** Credentials are stored securely and encrypted, never in plain text files.

### Step 3: Test Configuration (Optional)
```batch
powershell -ExecutionPolicy Bypass -File "scripts\test-credentials.ps1"
```
This will validate your credentials and API connectivity.

### Step 4: Run Data Export

#### **🤖 Automated Mode (Recommended)**
```batch
run_export.bat
```
**Fully automated operation:**
- **✅ Auto date calculation**: Jan 1 (current year) to today
- **✅ Secure credentials**: Loads from Windows Credential Manager
- **✅ Complete pipeline**: Extraction + CSV conversion + cleanup
- **✅ No user input required**: Runs hands-free

#### **Custom Date Range (Advanced)**
For specific date ranges, use the custom date script:
```batch
run_custom_dates.bat
```
This will prompt you to enter custom start/end dates, or use automatic dates.

You can also run scripts directly:
```powershell
# Automatic dates (default - full current year)
.\scripts\VEA-Zone-Extractor.ps1

# Custom dates with interactive prompts
.\scripts\VEA-Zone-Extractor-Custom.ps1
.\scripts\VEA-Zone-Extractor.ps1 -StartDate "2025-01-01T00:00:00Z" -EndDate "2025-12-31T23:59:59Z"
```

## 🕒 Windows Task Scheduler Setup

### Method 1: GUI Setup (Recommended)
1. **Open Task Scheduler** (`Win + R` → `taskschd.msc`)
2. **Create Task** (not Basic Task)
3. **General Tab**:
   - Name: `VEA Daily Export`
   - ☑ "Run whether user is logged on or not"
   - ☑ "Run with highest privileges"
4. **Triggers Tab**: Daily at preferred time (e.g., 6:00 AM)
5. **Actions Tab**:
   - Program: `"C:\path\to\vea springshare api\run_export.bat"`
   - Start in: `C:\path\to\vea springshare api`
6. **Save** and enter Windows password

### Method 2: PowerShell Command
```powershell
$action = New-ScheduledTaskAction -Execute "C:\path\to\vea springshare api\run_export.bat" -WorkingDirectory "C:\path\to\vea springshare api"
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Password -RunLevel Highest
Register-ScheduledTask -TaskName "VEA Daily Export" -Action $action -Trigger $trigger -Principal $principal -Description "Automated VEA data extraction for LibInsights"
```

### ✅ Task Scheduler Features
- **🔐 Secure**: Uses Windows Credential Manager (no passwords in task)
- **📅 Auto-dates**: Always extracts current year to date
- **🔄 Clean process**: Removes old files before creating new ones
- **📝 Logging**: Full console output for troubleshooting
- **🌐 Network-aware**: Only runs when network is available

### Step 4: Import to Springshare
- Use the CSV files from `output\csv\` folder
- Import each sensor CSV file separately in LibInsights

## Prerequisites

- Windows PowerShell 5.1 or higher
- Internet connection for VEA API access
- Valid VEA API credentials

## Project Structure

```
vea-springshare-api/
├── scripts/                    # Core application scripts
│   ├── VeaCredentialManager.ps1   # Secure credential management
│   ├── VeaValidator.ps1          # Input validation functions
│   ├── VeaExceptions.ps1         # Custom exception classes
│   ├── setup-automated.ps1      # Automated credential setup
│   ├── test-credentials.ps1      # Credential validation test
│   ├── VEA-Zone-Extractor.ps1    # Main data extraction script
│   └── VEA-Zone-Extractor-Custom.ps1 # Custom date extraction
├── output/                     # Generated data files
│   ├── csv/                   # Springshare-ready CSV files
│   └── json/                  # Raw VEA zone data
├── docs/                      # Documentation and templates
├── archive/                   # Development/test scripts
├── run_export.bat            # Main execution script
├── setup.bat                 # Secure setup script
└── README.md                 # This file
```

## 🤖 Automation & Scheduling

### Fully Automated Operation
- **📅 Smart Date Calculation**: Always extracts from January 1st (current year) to current date
- **🔄 Daily Updates**: Task Scheduler integration for automatic daily runs  
- **🔐 Zero Configuration**: Uses stored credentials, no manual input required
- **🧹 Clean Process**: Automatically removes old files before creating new ones
- **📊 Complete Pipeline**: Extraction → Processing → CSV Generation in one command

### Task Scheduler Integration  
- **🕒 Background Execution**: Runs whether user is logged in or not
- **🌐 Network Aware**: Only executes when network connection is available
- **🛡️ Elevated Privileges**: Runs with highest privileges for reliability
- **📝 Full Logging**: Complete console output captured for troubleshooting

## Security & Reliability

- 🔐 **Secure Credential Storage**: API credentials encrypted using Windows Credential Manager or environment variables
- ✅ **Input Validation**: Comprehensive parameter and credential validation
- 🛡️ **Error Handling**: Structured exception handling with retry logic
- 🔍 **Credential Testing**: Automated validation of API connectivity
- 🤖 **Automation Ready**: Supports both interactive and non-interactive credential management
- ⚡ **Retry Logic**: Automatic retry for transient network failures

## Features

- ✅ **Individual Sensor Data**: Extracts unique data for each sensor location
- ✅ **🤖 Automatic Date Calculation**: Always extracts from Jan 1 to current date
- ✅ **🔐 Secure Credential Management**: Windows Credential Manager integration
- ✅ **📅 Task Scheduler Ready**: Complete hands-free automation support
- ✅ **Springshare Compatible**: CSV format matches LibInsights requirements
- ✅ **Automated Pipeline**: Single-click execution via batch file
- ✅ **🧹 Smart Cleanup**: Removes duplicate files automatically
- ✅ **Error Handling**: Comprehensive validation and error reporting

## Output Files

The application generates individual CSV files for each sensor:
- `McKay_Library_Level_1_Main_Entrance_1_individual_springshare_import.csv`
- `McKay_Library_Level_1_New_Entrance_individual_springshare_import.csv`
- `McKay_Library_Level_2_Stairs_individual_springshare_import.csv`
- `McKay_Library_Level_3_Bridge_individual_springshare_import.csv`
- `McKay_Library_Level_3_Stairs_individual_springshare_import.csv`

Each file contains **hourly** traffic data with columns:
- `date` - Date in YYYY-MM-DD format  
- `time` - Time in HH:mm format (24-hour, Mountain Time)
- `gate_start` - Entry count for the hour
- `gate_end` - Exit count for the hour

**Data Coverage**: Automatic extraction from January 1st (current year) through current date with complete hourly granularity.

## Support

For technical issues or questions:
1. Check the troubleshooting section in `docs/TROUBLESHOOTING.md`
2. Review the script documentation in `docs/SCRIPTS.md`
3. Verify your VEA API credentials and permissions

## Implementation Status

### ✅ VEA Data Extraction - **COMPLETED**
- **Full automation**: Automatic date ranges, secure credentials, Task Scheduler ready
- **Individual sensor data**: 5 sensors with hourly granularity
- **Robust pipeline**: Error handling, retries, validation, cleanup
- **Springshare compatible**: CSV format matches LibInsights requirements

### ✅ LibInsights Integration - **COMPLETED** 
- **CSV Import**: Successfully tested with LibInsights CSV import feature
- **Format compatibility**: Proper date/time columns, timezone conversion (UTC → Mountain Time)
- **Data mapping**: gate_start (entries) and gate_end (exits) columns
- **Hourly distribution**: Resolved timezone issues for proper hourly traffic analysis

## Data Processing Pipeline

1. **🔐 Authentication**: Secure credential loading from Windows Credential Manager
2. **📅 Date Calculation**: Automatic range from Jan 1 (current year) to current date  
3. **📡 API Extraction**: VEA zone data with hourly granularity (UTC timestamps)
4. **🕒 Timezone Conversion**: UTC → Mountain Time for LibInsights compatibility
5. **📊 CSV Generation**: Individual sensor files with proper date/time columns
6. **🧹 Cleanup**: Remove duplicate files, maintain clean output directory

## Conclusion

✅ **Complete end-to-end automation** - VEA extraction to LibInsights import  
✅ **Task Scheduler ready** - Hands-free daily operation  
✅ **Production tested** - Timezone handling, data validation, error recovery  
🔧 **Zero dependencies** - Pure PowerShell solution, no external tools required

**Result**: Fully operational pipeline for automated daily extraction of VEA sensor data and LibInsights import preparation.