# Installation and Setup Guide

This guide walks you through installing and configuring the VEA to Springshare LibInsights data pipeline.

## Prerequisites

### System Requirements
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher (pre-installed on modern Windows)
- **Network**: Internet access to reach VEA API endpoints
- **Permissions**: Ability to run PowerShell scripts (see PowerShell setup below)

### VEA API Requirements
- Valid VEA account with API access
- API Client ID and Client Secret

- Active sensors configured in VEA system

### Springshare Requirements
- LibInsights account with import permissions
- Access to add custom data sources

## Installation Steps

### Step 1: Clone the Repository

1. **Clone from GitHub**:
   ```bash
   git clone https://github.com/matjmiles/SenSourceToLibInsights.git
   cd SenSourceToLibInsights
   ```

2. **Alternative - Download ZIP**:
   - Download ZIP from GitHub repository
   - Extract to a folder like `C:\VEA-Springshare\`
   - Ensure all files maintain their folder structure

### Step 2: PowerShell Setup

#### Check PowerShell Version
```powershell
$PSVersionTable.PSVersion
```
Should show version 5.1 or higher.

#### Configure Execution Policy
Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This allows locally created scripts to run while maintaining security for downloaded scripts.

### Step 3: Configure VEA API Credentials

1. **Run Setup Script** (Recommended):
   ```batch
   setup.bat
   ```
   This will prompt you to enter your VEA API credentials and store them securely.

2. **Automated Setup** (Advanced):
   ```powershell
   .\scripts\setup-automated.ps1 -ClientId "your-id" -ClientSecret "your-secret"
   ```

3. **Obtain VEA Credentials**:
   - Log into your VEA dashboard
   - Navigate to API settings or contact VEA support
   - Note your Client ID and Client Secret

The setup script will store your credentials securely using Windows Credential Manager.

## Security Note

**🔒 Your API credentials are secure:**
- Credentials are stored in Windows Credential Manager (encrypted)
- No plain text credential files in your repository
- Safe to clone, fork, or share the repository without exposing sensitive data
- Supports both interactive and automated credential setup

### Step 4: Test Installation

1. **Open PowerShell**:
   - Navigate to your installation directory
   - Right-click in the folder and select "Open PowerShell window here"

2. **Test VEA Connection**:
   ```batch
   .\run_export.bat
   ```
   When prompted, enter a date range like:
   - Start date: `2025-12-01`
   - End date: `2025-12-08`

3. **Expected Output**:
   ```
   ====================================================
   VEA TO SPRINGSHARE LIBINSIGHTS EXPORT PIPELINE
   ====================================================
   
   Step 1: Extracting individual sensor data from VEA API...
   --------------------------------------------------------
   [Output showing zone extraction progress]
   
   Step 2: Converting zone data to individual sensor CSVs...
   ---------------------------------------------------------
   [Output showing CSV generation progress]
   
   ====================================================
   EXPORT COMPLETE!
   ====================================================
   ```

## Configuration Options

### Date Range Customization

Edit the date variables in `scripts\VEA-Zone-Extractor.ps1`:

```powershell
# For last 7 days
$EndDate = (Get-Date).ToString("yyyy-MM-ddT23:59:59Z")
$StartDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddT00:00:00Z")

# For specific date range
$StartDate = "2025-12-01T00:00:00Z"
$EndDate = "2025-12-31T23:59:59Z"

# For current month
$StartDate = (Get-Date -Day 1).ToString("yyyy-MM-ddT00:00:00Z")
$EndDate = (Get-Date -Day 1).AddMonths(1).AddDays(-1).ToString("yyyy-MM-ddT23:59:59Z")
```

## Running the Application

### Automated Execution (Recommended)
```batch
run_export.bat
```
The script automatically extracts data for the current year and generates both JSON and CSV files.

### Custom Date Range
```batch
run_custom_dates.bat
```
Allows you to specify custom start and end dates for data extraction.

### Scheduled Execution
To run automatically, create a Windows Task Scheduler task:

1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (daily, weekly, etc.)
4. Set action to run: `C:\path\to\your\run_export.bat`

## Output and File Locations

### Generated Files Structure
```
vea-springshare-api/
├── output/
│   ├── csv/                                    # Ready for Springshare import
│   │   ├── McKay_Library_Level_1_Main_Entrance_1_individual_springshare_import.csv
│   │   ├── McKay_Library_Level_1_New_Entrance_individual_springshare_import.csv
│   │   ├── McKay_Library_Level_2_Stairs_individual_springshare_import.csv
│   │   ├── McKay_Library_Level_3_Bridge_individual_springshare_import.csv
│   │   └── McKay_Library_Level_3_Stairs_individual_springshare_import.csv
│   └── json/                                   # Raw VEA data (backup)
│       ├── McKay_Library_Level_1_Main_Entrance_1_zone_data.json
│       └── [other zone data files...]
```

## Importing to Springshare LibInsights

### Step 1: Access LibInsights
1. Log into your Springshare account
2. Navigate to LibInsights
3. Go to Data Sources or Import section

### Step 2: Import Individual Sensor Files
1. **Important**: Import each CSV file as a separate data source
2. Select "Import from CSV" option
3. Upload one CSV file at a time
4. Configure each import:
   - **Name**: Use sensor location (e.g., "Main Entrance Level 1")
   - **Date Column**: Select "date"
   - **Value Columns**: Select "gate_start" and "gate_end"
   - **Data Type**: Traffic/Gate data

### Step 3: Verify Data
1. Check that each sensor shows as separate data source
2. Verify date ranges match your extraction period
3. Confirm entry/exit counts look reasonable
4. Test creating reports with individual sensor data

## Troubleshooting

### Common Installation Issues

#### PowerShell Execution Policy Error
```
Error: Execution of scripts is disabled on this system
```
**Solution**: Run as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### VEA Authentication Failure
```
Error: 401 Unauthorized
```
**Solution**: 
1. Verify Client ID and Client Secret are correct
2. Check that credentials haven't expired
3. Ensure Site ID matches your VEA account
4. Contact VEA support if credentials are valid but failing

#### No Zone Data Retrieved
```
Warning: No zones found for site
```
**Solution**:
1. Verify Site ID is correct
2. Check that sensors are active in VEA dashboard
3. Ensure your account has permissions to access sensor data
4. Try a different date range

#### Empty CSV Files
```
Warning: CSV file contains no data
```
**Solution**:
1. Check date range - ensure sensors had activity during specified period
2. Verify zone data JSON files contain records
3. Check that zone IDs are being filtered correctly

### Getting Support

1. **Check Logs**: Run scripts with `-Verbose` flag for detailed logging
2. **Verify Credentials**: Test VEA API access independently
3. **File Permissions**: Ensure write access to output directories
4. **Network Connectivity**: Verify access to VEA API endpoints

### Advanced Configuration

#### Custom Output Paths
Edit the scripts to change default output locations:
```powershell
# In VEA-Zone-Extractor.ps1
# Output paths are built-in and organized automatically
# JSON: output/json/{SensorName}_zone_data.json
# CSV: output/csv/occupancy/{FriendlyName}.csv and output/csv/gate_counts/{FriendlyName}.csv
```

#### API Timeout Settings
For slow connections, increase timeout values:
```powershell
# In API calls, add timeout
Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 300
```

## Maintenance

### Regular Tasks
- **Weekly**: Run export to get fresh data
- **Monthly**: Verify VEA credentials haven't expired
- **Quarterly**: Check for script updates
- **As Needed**: Update date ranges for different reporting periods

### File Cleanup
The pipeline automatically cleans up old files, but you can manually remove:
- Old JSON files from `output\json\` (keep for backup/troubleshooting)
- Processed CSV files after Springshare import
- Log files if logging is enabled

### Updates and Maintenance
- Keep VEA credentials current
- Monitor VEA API for changes
- Update Springshare import format if requirements change
- Test pipeline after any system updates