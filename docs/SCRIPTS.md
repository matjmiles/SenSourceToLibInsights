# Scripts Documentation

This document explains how each script works in the VEA to Springshare data pipeline.

## Core Scripts

### 1. VEA-Zone-Extractor.ps1

**Purpose**: Extracts individual sensor data from VEA API using zone-based approach

**How it Works**:
1. **Authentication**: Uses OAuth 2.0 to get access token from VEA API
2. **Zone Discovery**: Retrieves list of all zones (sensors) from VEA
3. **Data Extraction**: For each zone, extracts traffic data using `entityType=zone` parameter
4. **Date Range**: Supports custom start/end dates via `relativeDate=custom`
5. **Output**: Creates individual JSON files for each zone with raw traffic data

**Key Parameters**:
- `$ClientId` - Your VEA API client ID
- `$ClientSecret` - Your VEA API client secret  
- `$SiteId` - Your VEA site identifier
- `$StartDate` - Data extraction start date (ISO-8601 format)
- `$EndDate` - Data extraction end date (ISO-8601 format)

**Configuration**:
```powershell
# Edit these variables in the script
$ClientId = "your-client-id"
$ClientSecret = "your-client-secret"
$SiteId = "your-site-id"
$StartDate = "2025-12-01T00:00:00Z"
$EndDate = "2025-12-08T23:59:59Z"
```

**Output Files**:
- `{SensorName}_zone_data.json` - Raw zone data from VEA API

---

### 2. VEA-Zone-CSV-Processor.ps1

**Purpose**: Converts individual zone JSON files to Springshare-compatible CSV format

**How it Works**:
1. **Zone Filtering**: Filters zone data to only include records for specific zone ID
2. **Data Aggregation**: Groups traffic data by day and sums entries/exits
3. **Bidirectional Calculation**: Calculates proper entry/exit counts based on traffic direction
4. **CSV Generation**: Creates UTF-8 encoded CSV with required Springshare columns

**Key Features**:
- Client-side filtering by `zoneId` to ensure individual sensor data
- Daily aggregation from hourly/interval data
- Proper handling of bidirectional traffic sensors
- UTF-8 encoding without BOM for Springshare compatibility

**Parameters**:
- `-ZoneJsonFile` - Path to zone JSON data file
- `-OutputPath` - Where to save the CSV file
- `-GateMethod` - "Bidirectional" or "Unidirectional" counting method

**Usage Example**:
```powershell
.\VEA-Zone-CSV-Processor.ps1 -ZoneJsonFile "output\json\Main_Entrance_zone_data.json" -OutputPath "output\csv\Main_Entrance_springshare.csv" -GateMethod "Bidirectional"
```

---

### 3. VEA-Generate-All-Individual-CSVs.ps1

**Purpose**: Batch processor that converts all zone JSON files to individual sensor CSV files

**How it Works**:
1. **File Discovery**: Finds all `*_zone_data.json` files in the current directory
2. **Batch Processing**: Processes each zone file using the CSV processor logic
3. **Individual Filtering**: Ensures each CSV contains only data for that specific sensor
4. **File Management**: Creates properly named output files and cleans up duplicates
5. **Progress Reporting**: Shows processing status and summary statistics

**Key Features**:
- Automatic processing of all zone files
- Individual sensor data validation (ensures unique data per sensor)
- Comprehensive error handling and progress reporting
- Automatic cleanup of duplicate/old files
- Summary statistics showing entries/exits per sensor

**Parameters**:
- `-GateMethod` - "Bidirectional" or "Unidirectional" counting method

**Usage**:
```powershell
.\VEA-Generate-All-Individual-CSVs.ps1 -GateMethod "Bidirectional"
```

**Output**:
- Individual CSV files for each sensor with format: `{SensorName}_individual_springshare_import.csv`

---

## Data Flow Pipeline

```
1. VEA-Zone-Extractor.ps1
   ↓ Extracts zone data from VEA API
   ↓ Creates: {sensor}_zone_data.json files

2. VEA-Generate-All-Individual-CSVs.ps1
   ↓ Processes all zone JSON files
   ↓ Filters by zoneId for individual sensor data
   ↓ Aggregates daily totals
   ↓ Creates: {sensor}_individual_springshare_import.csv files

3. Manual Import
   ↓ Upload CSV files to Springshare LibInsights
   ↓ Each sensor imports as separate dataset
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
- **Columns**: `date,gate_start,gate_end`
- **Date Format**: YYYY-MM-DD
- **Data Type**: Daily aggregated counts

### Error Handling
- OAuth token refresh if expired
- Network connectivity validation
- JSON parsing error handling
- CSV encoding validation
- File permission checks

## Troubleshooting

### Common Issues
1. **Authentication Failures**: Check ClientId, ClientSecret, and network connectivity
2. **No Zone Data**: Verify SiteId and that sensors are active in VEA
3. **Empty CSV Files**: Check date range - ensure data exists for specified dates
4. **Encoding Issues**: Scripts use UTF-8 without BOM - required for Springshare

### Debug Mode
Add `-Verbose` parameter to any script for detailed logging:
```powershell
.\VEA-Zone-Extractor.ps1 -Verbose
```