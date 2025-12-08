# VEA API Data Extractor with Date Range Support
# Complete script to extract data from VEA API with customizable date ranges

param(
    [Parameter(Mandatory=$false)]
    [string]$StartDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd"),
    
    [Parameter(Mandatory=$false)]
    [string]$EndDate = (Get-Date).ToString("yyyy-MM-dd"),
    
    [Parameter(Mandatory=$false)]
    [string]$DataType = "traffic",  # traffic, occupancy, pos, queue, etc.
    
    [Parameter(Mandatory=$false)]
    [string]$DateGrouping = "hour", # minute(15), hour, hour(4), day, week, month
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "vea_data_export.json"
)

# VEA API Configuration
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com"

Write-Host "=== VEA API Data Extractor ===" -ForegroundColor Green
Write-Host "Start Date: $StartDate" -ForegroundColor Yellow
Write-Host "End Date: $EndDate" -ForegroundColor Yellow
Write-Host "Data Type: $DataType" -ForegroundColor Yellow
Write-Host "Date Grouping: $DateGrouping" -ForegroundColor Yellow

# Function to authenticate and get access token
function Get-VEAAccessToken {
    Write-Host "`nStep 1: Authenticating..." -ForegroundColor Cyan
    
    $AuthBody = @{
        "grant_type" = "client_credentials"
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
    } | ConvertTo-Json

    $Headers = @{ "Content-Type" = "application/json" }

    try {
        $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers -ErrorAction Stop
        Write-Host "✓ Authentication successful!" -ForegroundColor Green
        Write-Host "  Token expires in: $($Response.expires_in) seconds" -ForegroundColor Gray
        return $Response.access_token
    }
    catch {
        Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to get available sites/sensors
function Get-VEASites {
    param([string]$AccessToken)
    
    Write-Host "`nStep 2: Getting available sites..." -ForegroundColor Cyan
    
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }
    
    try {
        $Sites = Invoke-RestMethod -Uri "$ApiBaseUrl/site" -Method Get -Headers $Headers -ErrorAction Stop
        Write-Host "✓ Found $($Sites.Count) sites" -ForegroundColor Green
        
        foreach ($site in $Sites) {
            Write-Host "  - Site: $($site.name) (ID: $($site.id))" -ForegroundColor White
        }
        
        return $Sites
    }
    catch {
        Write-Host "✗ Failed to get sites: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Function to extract data with date range
function Get-VEAData {
    param(
        [string]$AccessToken,
        [string]$DataType,
        [string]$StartDate,
        [string]$EndDate,
        [string]$DateGrouping
    )
    
    Write-Host "`nStep 3: Extracting $DataType data..." -ForegroundColor Cyan
    
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }
    
    # Build query parameters
    $QueryParams = @{
        "relativeDate" = "custom"
        "startDate" = $StartDate
        "endDate" = $EndDate
        "dateGroupings" = $DateGrouping
    }
    
    # Convert to query string
    $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
    $DataUrl = "$ApiBaseUrl/data/$DataType" + "?" + $QueryString
    
    Write-Host "  Request URL: $DataUrl" -ForegroundColor Gray
    
    try {
        $Data = Invoke-RestMethod -Uri $DataUrl -Method Get -Headers $Headers -ErrorAction Stop
        Write-Host "✓ Successfully retrieved $DataType data" -ForegroundColor Green
        
        if ($Data -is [array]) {
            Write-Host "  Records returned: $($Data.Count)" -ForegroundColor White
        } else {
            Write-Host "  Data structure: $($Data.GetType().Name)" -ForegroundColor White
        }
        
        return $Data
    }
    catch {
        Write-Host "✗ Failed to get $DataType data: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Main execution
try {
    # Step 1: Authenticate
    $AccessToken = Get-VEAAccessToken
    if (-not $AccessToken) {
        throw "Authentication failed"
    }
    
    # Step 2: Get sites (for reference)
    $Sites = Get-VEASites -AccessToken $AccessToken
    
    # Step 3: Extract data
    $Data = Get-VEAData -AccessToken $AccessToken -DataType $DataType -StartDate $StartDate -EndDate $EndDate -DateGrouping $DateGrouping
    
    if ($Data) {
        # Step 4: Save data to file
        Write-Host "`nStep 4: Saving data..." -ForegroundColor Cyan
        
        $ExportData = @{
            "extraction_date" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            "parameters" = @{
                "start_date" = $StartDate
                "end_date" = $EndDate
                "data_type" = $DataType
                "date_grouping" = $DateGrouping
            }
            "sites" = $Sites
            "data" = $Data
        }
        
        $ExportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "✓ Data saved to: $OutputFile" -ForegroundColor Green
        
        # Show summary
        Write-Host "`n=== Data Summary ===" -ForegroundColor Green
        Write-Host "Extraction Date: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor White
        Write-Host "Data Type: $DataType" -ForegroundColor White
        Write-Host "Grouping: $DateGrouping" -ForegroundColor White
        Write-Host "Output File: $OutputFile" -ForegroundColor White
        
        if ($Data -is [array] -and $Data.Count -gt 0) {
            Write-Host "Sample data structure:" -ForegroundColor Yellow
            $Data[0] | ConvertTo-Json -Depth 2 | Write-Host
        }
    } else {
        Write-Host "✗ No data retrieved" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Extraction Complete ===" -ForegroundColor Green