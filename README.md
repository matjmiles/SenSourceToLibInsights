# VEA to Springshare LibInsights Data Pipeline

This application extracts individual sensor traffic data from the VEA (Visitor Experience Analytics) API and converts it to CSV format for import into Springshare LibInsights.

## Quick Start

1. **Install Prerequisites**
   - Windows PowerShell 5.1 or higher
   - Internet connection for VEA API access
   - Valid VEA API credentials

2. **Configure Credentials**
   - Edit `scripts\VEA-Zone-Extractor.ps1`
   - Update the `$ClientId`, `$ClientSecret`, and `$SiteId` variables with your VEA credentials

3. **Run Export**
   ```batch
   run_export.bat
   ```
   The script will prompt you for:
   - Start date (yyyy-mm-dd format)
   - End date (yyyy-mm-dd format)

4. **Import to Springshare**
   - Use the CSV files from `output\csv\` folder
   - Import each sensor CSV file separately in LibInsights

## Project Structure

```
vea-springshare-api/
├── scripts/                    # Core application scripts
├── output/                     # Generated data files
│   ├── csv/                   # Springshare-ready CSV files
│   └── json/                  # Raw VEA zone data
├── docs/                      # Documentation and templates
├── archive/                   # Development/test scripts
├── run_export.bat            # Main execution script
└── README.md                 # This file
```

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