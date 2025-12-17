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

#### **Interactive Mode**
```batch
run_export.bat
```
Automatically extracts data from:
- **Start date**: First day of current year
- **End date**: Current date (end of today)

#### **Custom Date Range (Advanced)**
If you need a specific date range:
```powershell
.\scripts\VEA-Zone-Extractor.ps1 -StartDate "2025-01-01T00:00:00Z" -EndDate "2025-12-31T23:59:59Z"
```

#### **Automated Mode (Task Scheduler)**
For scheduled/automated runs, set credentials using environment variables:
```powershell
# Configure for automation
.\scripts\setup-automated.ps1 -ClientId "your-client-id" -ClientSecret "your-client-secret" -UseEnvironmentVariables

# Then run non-interactively
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1" -StartDate "2025-12-01T00:00:00Z" -EndDate "2025-12-02T00:00:00Z"
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Generate-All-Individual-CSVs.ps1" -GateMethod "Bidirectional"
```

#### **Task Scheduler Setup**
1. Create a new task in Task Scheduler
2. Set the program to: `powershell.exe`
3. Set arguments: `-ExecutionPolicy Bypass -File "C:\path\to\scripts\VEA-Zone-Extractor.ps1" -StartDate "2025-12-01T00:00:00Z" -EndDate "2025-12-02T00:00:00Z"`
4. Configure credentials using environment variables (not task credentials)

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
│   ├── setup-credentials.ps1     # Secure credential setup
│   ├── test-credentials.ps1      # Credential validation test
│   ├── VEA-Zone-Extractor.ps1    # Data extraction script
│   ├── VEA-Zone-CSV-Processor.ps1 # CSV processing
│   └── VEA-Generate-All-Individual-CSVs.ps1 # Batch processor
├── output/                     # Generated data files
│   ├── csv/                   # Springshare-ready CSV files
│   └── json/                  # Raw VEA zone data
├── docs/                      # Documentation and templates
├── archive/                   # Development/test scripts
├── run_export.bat            # Main execution script
├── setup.bat                 # Secure setup script
└── README.md                 # This file
```

## Security & Reliability

- 🔐 **Secure Credential Storage**: API credentials encrypted using Windows Credential Manager or environment variables
- ✅ **Input Validation**: Comprehensive parameter and credential validation
- 🛡️ **Error Handling**: Structured exception handling with retry logic
- 🔍 **Credential Testing**: Automated validation of API connectivity
- 🤖 **Automation Ready**: Supports both interactive and non-interactive credential management
- ⚡ **Retry Logic**: Automatic retry for transient network failures

## Features

- ✅ **Individual Sensor Data**: Extracts unique data for each sensor location
- ✅ **Date Range Support**: Configurable start and end dates
- ✅ **Springshare Compatible**: CSV format matches LibInsights requirements
- ✅ **Automated Pipeline**: Single-click execution via batch file
- ✅ **Error Handling**: Comprehensive validation and error reporting

## Output Files

The application generates individual CSV files for each sensor:
- `McKay_Library_Level_1_Main_Entrance_1_individual_springshare_import.csv`
- `McKay_Library_Level_1_New_Entrance_individual_springshare_import.csv`
- `McKay_Library_Level_2_Stairs_individual_springshare_import.csv`
- `McKay_Library_Level_3_Bridge_individual_springshare_import.csv`
- `McKay_Library_Level_3_Stairs_individual_springshare_import.csv`

Each file contains daily traffic data with columns:
- `date` - Date in YYYY-MM-DD format
- `gate_start` - Entry count for the day
- `gate_end` - Exit count for the day

## Support

For technical issues or questions:
1. Check the troubleshooting section in `docs/TROUBLESHOOTING.md`
2. Review the script documentation in `docs/SCRIPTS.md`
3. Verify your VEA API credentials and permissions

### **Implementation**: Two-Step Process

#### Step 1: Extract from VEA ✅ **COMPLETED**
Use the provided PowerShell script: `VEA-DataExtractor-Final.ps1`

**Usage Examples:**
```powershell
# Basic usage (last 7 days)
.\VEA-DataExtractor-Final.ps1

# Custom date range
.\VEA-DataExtractor-Final.ps1 -StartDate '2025-12-01' -EndDate '2025-12-07'

# Different data types
.\VEA-DataExtractor-Final.ps1 -DataType 'occupancy'
.\VEA-DataExtractor-Final.ps1 -DataType 'pos'

# Different time groupings
.\VEA-DataExtractor-Final.ps1 -DateGrouping 'day'
.\VEA-DataExtractor-Final.ps1 -DateGrouping 'minute(15)'
```

#### Step 2: Import to Springshare ❓ **NEEDS RESEARCH**
**Next Steps:**
1. **Contact Springshare Support** - Ask about LibInsights data import capabilities
2. **Check LibInsights UI** - Look for bulk import features
3. **Alternative solutions** - Consider custom dashboard or middleware

## Data Format

The VEA API returns well-structured data with:
- **Timestamps** in ISO-8601 format
- **Traffic data**: `sumins` (entries) and `sumouts` (exits) 
- **Hourly granularity** with precise datetime stamps
- **JSON format** that's easy to process

## Files Created

1. **`VEA-DataExtractor-Final.ps1`** - Main extraction script
2. **`vea_api_spec.json`** - Complete API specification
3. **Sample data files** - JSON exports with timestamp, parameters, and data

## Conclusion

✅ **VEA data extraction is simple and robust**
❓ **Springshare integration requires further investigation**
🔧 **PowerShell script provides flexible, no-dependency solution**

The simplest approach is definitely the PowerShell script - it requires no external tools and handles all the authentication and date range logic automatically.