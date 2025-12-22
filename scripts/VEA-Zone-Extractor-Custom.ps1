# VEA Zone Extractor - Custom Date Range
# Prompts user for custom date range and then modifies and runs the main extraction script

Write-Host "VEA Zone Extractor - Custom Date Range" -ForegroundColor Green
Write-Host "This script allows you to specify custom start and end dates for data extraction." -ForegroundColor Cyan
Write-Host ""

# Prompt for start date
do {
    $StartDateInput = Read-Host "Enter start date (YYYY-MM-DD) or press Enter for auto"
    
    if ([string]::IsNullOrWhiteSpace($StartDateInput)) {
        $UseCustomDates = $false
        Write-Host "Using automatic date range (full current year)" -ForegroundColor Green
        break
    }
    
    try {
        $ParsedStartDate = [DateTime]::ParseExact($StartDateInput, "yyyy-MM-dd", $null)
        $StartDate = $ParsedStartDate.ToString("yyyy-MM-ddT00:00:00Z")
        Write-Host "Start Date: $StartDate" -ForegroundColor Green
        $UseCustomDates = $true
        break
    } catch {
        Write-Host "Invalid date format. Please use YYYY-MM-DD (e.g., 2025-11-01)" -ForegroundColor Red
    }
} while ($true)

# Prompt for end date if custom dates are being used
if ($UseCustomDates) {
    do {
        $EndDateInput = Read-Host "Enter end date (YYYY-MM-DD)"
        
        try {
            $ParsedEndDate = [DateTime]::ParseExact($EndDateInput, "yyyy-MM-dd", $null)
            $EndDate = $ParsedEndDate.ToString("yyyy-MM-ddT23:59:59Z")
            Write-Host "End Date: $EndDate" -ForegroundColor Green
            break
        } catch {
            Write-Host "Invalid date format. Please use YYYY-MM-DD (e.g., 2025-11-30)" -ForegroundColor Red
        }
    } while ($true)
}

# Prompt for other parameters
Write-Host ""
Write-Host "Optional parameters (press Enter for defaults):" -ForegroundColor Cyan

$DataType = Read-Host "Data Type [traffic]"
if ([string]::IsNullOrWhiteSpace($DataType)) { $DataType = "traffic" }

$DateGrouping = Read-Host "Date Grouping [hour]"
if ([string]::IsNullOrWhiteSpace($DateGrouping)) { $DateGrouping = "hour" }

$GateMethod = Read-Host "Gate Method [Bidirectional]"
if ([string]::IsNullOrWhiteSpace($GateMethod)) { $GateMethod = "Bidirectional" }

Write-Host ""
Write-Host "Running extraction with parameters:" -ForegroundColor Yellow
if ($UseCustomDates) {
    Write-Host "  Start Date: $StartDate" -ForegroundColor White
    Write-Host "  End Date: $EndDate" -ForegroundColor White
} else {
    Write-Host "  Date Range: Auto (current year)" -ForegroundColor White
}
Write-Host "  Data Type: $DataType" -ForegroundColor White
Write-Host "  Date Grouping: $DateGrouping" -ForegroundColor White
Write-Host "  Gate Method: $GateMethod" -ForegroundColor White
Write-Host ""

$Confirm = Read-Host "Proceed with extraction? (Y/n)"
if ($Confirm -eq "" -or $Confirm -eq "Y" -or $Confirm -eq "y") {
    Write-Host "Starting extraction..." -ForegroundColor Green
    
    if ($UseCustomDates) {
        # For custom dates, we need to temporarily modify the main script
        $mainScript = "scripts\VEA-Zone-Extractor.ps1"
        $backupScript = "scripts\VEA-Zone-Extractor.ps1.backup"
        
        # Create backup
        Copy-Item $mainScript $backupScript
        
        try {
            # Read the main script content
            $scriptContent = Get-Content $mainScript -Raw
            
            # Replace the automatic date calculation with custom dates
            $customDateLogic = @"
# Calculate automatic date range for current year
Write-Host "Using custom date range..." -ForegroundColor Cyan
`$StartDate = "$StartDate"
`$EndDate = "$EndDate"
Write-Host "Custom Start Date: `$StartDate" -ForegroundColor Gray
Write-Host "Custom End Date: `$EndDate" -ForegroundColor Gray
"@
            
            $scriptContent = $scriptContent -replace '# Calculate automatic date range for current year[\s\S]*?Write-Host "Auto End Date: \$EndDate" -ForegroundColor Gray', $customDateLogic
            
            # Write modified script
            Set-Content $mainScript $scriptContent -Encoding UTF8
            
            # Run the modified script
            powershell -ExecutionPolicy Bypass -File $mainScript -DataType $DataType -DateGrouping $DateGrouping -GateMethod $GateMethod
            
        } finally {
            # Restore the original script
            Move-Item $backupScript $mainScript -Force
            Write-Host "Restored original script" -ForegroundColor Gray
        }
    } else {
        # For automatic dates, just run the script normally
        powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1" -DataType $DataType -DateGrouping $DateGrouping -GateMethod $GateMethod
    }
} else {
    Write-Host "Extraction cancelled." -ForegroundColor Yellow
}