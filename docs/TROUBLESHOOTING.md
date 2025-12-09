# Troubleshooting Guide

This guide helps resolve common issues with the VEA to Springshare data pipeline.

## Common Issues and Solutions

### 1. Configuration Issues

#### "Configuration file not found: config.ps1"
**Cause**: Missing configuration file with API credentials
**Solution**:
1. Run `setup.bat` to create config.ps1 from template
2. Or manually copy `config.example.ps1` to `config.ps1`
3. Edit `config.ps1` with your actual VEA API credentials

#### "Cannot find config.ps1" when running scripts
**Cause**: Configuration file not in correct location
**Solution**:
```powershell
# Verify config.ps1 exists in project root
ls config.ps1
# If not found, create from template
copy config.example.ps1 config.ps1
```

### 2. PowerShell Execution Issues

#### "Execution of scripts is disabled on this system"
**Cause**: PowerShell execution policy restricts script execution
**Solution**:
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### "File cannot be loaded because running scripts is disabled"
**Cause**: Stricter execution policy
**Solution**:
```powershell
# Temporarily bypass for single execution
powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1"
```

### 2. VEA API Authentication Issues

#### "401 Unauthorized" or "403 Forbidden"
**Causes & Solutions**:

1. **Invalid Credentials**:
   ```powershell
   # Verify credentials in config.ps1
   $ClientId = "correct-client-id"
   $ClientSecret = "correct-client-secret" 
   $SiteId = "correct-site-id"
   ```

2. **Expired Credentials**:
   - Contact VEA support to renew API access
   - Generate new Client ID/Secret if available

3. **Network/Proxy Issues**:
   ```powershell
   # Test basic connectivity
   Test-NetConnection -ComputerName "auth.sensourceinc.com" -Port 443
   ```

#### "Token expired" or "Invalid token"
**Solution**: The script handles token refresh automatically, but if issues persist:
```powershell
# Clear any cached tokens and retry
Remove-Variable AccessToken -ErrorAction SilentlyContinue
```

### 3. Data Extraction Issues

#### "No zones found for site"
**Causes & Solutions**:

1. **Incorrect Site ID**:
   - Verify Site ID in VEA dashboard
   - Check with VEA administrator

2. **No Active Sensors**:
   - Confirm sensors are online in VEA dashboard
   - Check sensor status and configuration

3. **Permissions Issue**:
   - Ensure API account has access to sensor data
   - Contact VEA support for permission verification

#### "Empty zone data files"
**Causes & Solutions**:

1. **Date Range Issues**:
   ```powershell
   # Verify date format (ISO-8601 required)
   $StartDate = "2025-12-01T00:00:00Z"  # Correct
   $EndDate = "2025-12-08T23:59:59Z"    # Correct
   
   # NOT: "12/1/2025" or "Dec 1, 2025"
   ```

2. **No Data in Date Range**:
   - Check VEA dashboard for activity in specified period
   - Try broader date range
   - Verify sensors were operational

3. **API Rate Limiting**:
   - Add delays between API calls if needed
   - Contact VEA about rate limits

### 4. CSV Generation Issues

#### "Measure-Object : The property 'Entries' cannot be found"
**Cause**: PowerShell trying to calculate totals on empty data
**Solution**: This warning can be ignored - it occurs when no data exists for summary calculations but doesn't affect CSV generation

#### "CSV files are empty"
**Causes & Solutions**:

1. **Zone Filtering Issue**:
   ```powershell
   # Debug zone filtering
   $ZoneRecords = $AllRecords | Where-Object { $_.zoneId -eq $TargetZoneId }
   Write-Host "Found $($ZoneRecords.Count) records for zone $TargetZoneId"
   ```

2. **Date Parsing Problems**:
   - Verify date format in JSON data
   - Check timezone handling

3. **Aggregation Logic Error**:
   - Review daily grouping logic
   - Verify entry/exit calculation method

#### "UTF-8 encoding issues in Springshare"
**Solution**:
```powershell
# Ensure proper encoding in CSV generation
$CsvData | Out-File -FilePath $OutputPath -Encoding UTF8NoBOM
```

### 5. File System Issues

#### "Access denied" or "File in use"
**Solutions**:
1. **Run as Administrator**: Right-click PowerShell and "Run as administrator"
2. **Close Excel/Text Editors**: Ensure CSV files aren't open elsewhere
3. **Check Permissions**: Verify write access to output folders

#### "Path not found"
**Solutions**:
1. **Create Directories**:
   ```powershell
   New-Item -ItemType Directory -Path "output\csv" -Force
   New-Item -ItemType Directory -Path "output\json" -Force
   ```

2. **Use Absolute Paths**: Avoid relative path issues
   ```powershell
   $OutputPath = "C:\Full\Path\To\Output\csv\"
   ```

### 6. Springshare Import Issues

#### "CSV format not recognized"
**Solution**: Verify CSV format exactly matches requirements:
```csv
date,gate_start,gate_end
2025-12-01,1234,5678
2025-12-02,2345,6789
```

#### "Date format invalid"
**Solution**: Ensure dates are in YYYY-MM-DD format:
```powershell
# Correct date formatting
$FormattedDate = $DateObj.ToString("yyyy-MM-dd")
```

#### "Data appears as single column"
**Solution**: Check CSV delimiter and encoding:
- Use comma separator (not semicolon)
- Ensure UTF-8 without BOM encoding
- Verify no extra quotes around values

### 7. Network and Connectivity Issues

#### "Unable to connect to remote server"
**Solutions**:

1. **Check Internet Connection**:
   ```powershell
   Test-NetConnection -ComputerName "api.sensourceinc.com" -Port 443
   ```

2. **Firewall/Proxy Issues**:
   - Configure PowerShell proxy settings if needed:
   ```powershell
   # If behind corporate proxy
   [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
   ```

3. **DNS Resolution**:
   ```powershell
   Resolve-DnsName "auth.sensourceinc.com"
   ```

### 8. Performance Issues

#### "Script runs very slowly"
**Solutions**:

1. **Reduce Date Range**: Process smaller time periods
2. **Add Progress Indicators**: Monitor script execution
3. **Optimize API Calls**: Implement parallel processing if needed

#### "Memory usage high"
**Solutions**:
```powershell
# Clear variables after use
Remove-Variable LargeDataSet -ErrorAction SilentlyContinue
[System.GC]::Collect()
```

## Debugging Techniques

### 1. Enable Verbose Logging
```powershell
# Run with detailed output
.\scripts\VEA-Zone-Extractor.ps1 -Verbose
```

### 2. Step-by-Step Debugging
```powershell
# Run individual components
# 1. Test authentication only
$Token = Get-VEAAccessToken -ClientId $ClientId -ClientSecret $ClientSecret

# 2. Test zone retrieval only  
$Zones = Get-VEAZones -AccessToken $Token -SiteId $SiteId

# 3. Test single zone data extraction
$ZoneData = Get-VEAZoneData -AccessToken $Token -ZoneId $Zones[0].id
```

### 3. API Response Inspection
```powershell
# Capture raw API responses
$Response = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers
$Response | ConvertTo-Json -Depth 10 | Out-File "debug_response.json"
```

### 4. Data Validation
```powershell
# Verify data structure
$JsonData = Get-Content "zone_data.json" | ConvertFrom-Json
Write-Host "Record count: $($JsonData.Count)"
Write-Host "Sample record: $($JsonData[0] | ConvertTo-Json)"
```

## Getting Additional Help

### 1. Log File Analysis
Enable detailed logging and review output:
```powershell
# Redirect all output to log file
.\run_export.bat > execution_log.txt 2>&1
```

### 2. Contact Information
- **VEA API Issues**: Contact VEA technical support
- **Springshare Import Issues**: Contact Springshare LibInsights support
- **Script Issues**: Review script documentation in `docs\SCRIPTS.md`

### 3. Community Resources
- PowerShell documentation: docs.microsoft.com/powershell
- REST API troubleshooting guides
- JSON processing tutorials

## Prevention Best Practices

### 1. Regular Testing
- Test credentials monthly
- Validate data extraction weekly
- Monitor API changes

### 2. Error Handling
- Implement comprehensive try-catch blocks
- Log errors with timestamps
- Set up email notifications for failures

### 3. Documentation
- Document any custom modifications
- Keep configuration changes tracked
- Maintain troubleshooting log

### 4. Backup Strategy
- Keep copies of working configurations
- Archive successful data extractions
- Maintain script version history