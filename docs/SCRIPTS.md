# Scripts Documentation

This document explains how each script works in the VEA to Springshare data pipeline.

## Core Scripts

### 1. VEA-Zone-Extractor.ps1

**Purpose**: Main data extraction script that retrieves VEA sensor data and generates both JSON and CSV files for Springshare import

**How it Works**:
1. **Authentication**: Uses OAuth 2.0 to get access token from VEA API
2. **Zone Discovery**: Retrieves list of all zones (sensors) from VEA
3. **Data Extraction**: For each zone, extracts traffic data using `entityType=zone` parameter
4. **Date Range**: Uses automatic last 7 days by default (no parameters required)
5. **CSV Generation**: Automatically creates both gate count and occupancy CSV files with friendly naming
6. **Output**: Creates both JSON data files and Springshare-ready CSV files

**Default Behavior** (No Parameters Required):
- Automatically extracts last 7 days of data
- Uses secure credential storage (no manual configuration needed)
- Generates friendly file names using "West Wing" convention
- Creates dual CSV formats: gate counts and occupancy data

**Credential Management**:
The script automatically retrieves credentials from secure storage:
- Windows Credential Manager (encrypted storage)
- Environment variables (for automation)
- No plain text configuration files needed

**Output Files**:
- `output/json/{SensorName}_zone_data.json` - Raw zone data from VEA API
- `output/csv/gate_counts/Gate Count West Wing Level X [Location].csv` - Gate count data
- `output/csv/occupancy/Occupancy West Wing Level X [Location].csv` - Occupancy data

---

### 2. VEA-Zone-Extractor-Custom.ps1

**Purpose**: Interactive script for extracting data with custom date ranges

**How it Works**:
1. **Interactive Prompts**: Asks user for custom start and end dates
2. **Script Modification**: Temporarily modifies the main extractor script with custom dates
3. **Execution**: Runs the main extractor with the specified date range
4. **Restoration**: Restores the original script after execution

**Usage**:
```powershell
.\VEA-Zone-Extractor-Custom.ps1
```

**Features**:
- Date validation and user-friendly prompts
- Automatic script backup and restoration
- Same output format as main extractor script
- Error handling for invalid date ranges



---

## Data Flow Pipeline

```
1. VEA-Zone-Extractor.ps1 (Main Script)
   ↓ Extracts zone data from VEA API (last 7 days by default)
   ↓ Applies friendly "West Wing" naming convention
   ↓ Creates: JSON files in output/json/
   ↓ Creates: CSV files in output/csv/gate_counts/ and output/csv/occupancy/

2. VEA-Zone-Extractor-Custom.ps1 (Optional)
   ↓ For custom date ranges
   ↓ Prompts user for dates
   ↓ Same output as main script

3. Manual Import
   ↓ Upload CSV files to Springshare LibInsights
   ↓ Choose either gate_counts or occupancy format as needed
```

## Technical Details

### VEA API Zone Architecture
- Each physical sensor corresponds to a logical "zone" in VEA
- Zone data API endpoint: `/data/traffic?entityType=zone`
- API returns all zones but records contain `zoneId` for filtering
- Individual sensor data is achieved through client-side zoneId filtering

### Springshare CSV Format Requirements
- **Encoding**: UTF-8 without BOM
- **Delimiter**: Comma (`,`)
- **Gate Count Format**: `date,gate_start` (for entry/exit counts)
- **Occupancy Format**: `date,gate_start,gate_end` (for occupancy tracking)
- **Date Format**: YYYY-MM-DD
- **Data Type**: Daily aggregated counts

### File Naming Convention
The scripts automatically apply a friendly naming convention:
- **Gate Count Files**: `Gate Count West Wing Level X [Location].csv`
- **Occupancy Files**: `Occupancy West Wing Level X [Location].csv`
- **JSON Files**: `{OriginalSensorName}_zone_data.json`

**Sensor Mapping**:
- McKay_Library_Level_1_Main_Entrance_1 → West Wing Level 1 East Side
- McKay_Library_Level_1_New_Entrance → West Wing Level 1 West Side
- McKay_Library_Level_2_Stairs → West Wing Level 2 Stairs
- McKay_Library_Level_3_Bridge → West Wing Level 3 Bridge
- McKay_Library_Level_3_Stairs → West Wing Level 3 Stairs

### Error Handling
- OAuth token refresh if expired
- Network connectivity validation
- JSON parsing error handling
- CSV encoding validation
- File permission checks

## Troubleshooting

### Common Issues
1. **Authentication Failures**: Check network connectivity and verify credentials with `setup.bat`
2. **No Zone Data**: Verify that sensors are active in VEA for the specified date range
3. **Empty CSV Files**: Check date range - ensure data exists for specified dates
4. **Encoding Issues**: Scripts automatically use UTF-8 without BOM - required for Springshare
5. **Missing Output Folders**: Scripts automatically create output/json, output/csv/gate_counts, and output/csv/occupancy directories

### Quick Testing
To verify the system is working:
1. Run `run_export.bat` for full extraction with default dates
2. Check `output/csv/gate_counts/` and `output/csv/occupancy/` for generated files
3. Files should use "West Wing" naming convention with recent timestamps

### Debug Mode
Add `-Verbose` parameter to any script for detailed logging:
```powershell
.\VEA-Zone-Extractor.ps1 -Verbose
```

### Running Scripts
- **Default extraction** (recommended): `run_export.bat`
- **Main script directly**: `powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1"`
- **Custom dates**: `powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor-Custom.ps1"`
- **Setup credentials**: `setup.bat`