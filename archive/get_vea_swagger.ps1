# Get VEA API Swagger Documentation
$ClientId = "f01cc7bb-e060-4965-bcda-612e2dc8d294"
$ClientSecret = "3b710165-fd3c-49a5-a869-4ed8a7eba99d"
$AuthUrl = "https://auth.sensourceinc.com/oauth/token"
$ApiBaseUrl = "https://vea.sensourceinc.com"

Write-Host "Getting VEA API Documentation..." -ForegroundColor Green

# Authenticate first
$AuthBody = @{
    "grant_type" = "client_credentials"
    "client_id" = $ClientId
    "client_secret" = $ClientSecret
} | ConvertTo-Json

$Headers = @{ "Content-Type" = "application/json" }

try {
    $TokenResponse = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $AuthBody -Headers $Headers
    $AccessToken = $TokenResponse.access_token
    Write-Host "Authenticated successfully" -ForegroundColor Green
}
catch {
    Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Try to get Swagger/OpenAPI docs
$ApiHeaders = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type" = "application/json"
}

$SwaggerEndpoints = @(
    "/swagger.json",
    "/api/swagger.json", 
    "/docs/swagger.json",
    "/openapi.json",
    "/api/openapi.json",
    "/v1/swagger.json",
    "/api-docs/swagger.json"
)

foreach ($endpoint in $SwaggerEndpoints) {
    $FullUrl = "$ApiBaseUrl$endpoint"
    Write-Host "Trying: $FullUrl" -ForegroundColor Gray
    
    try {
        $Response = Invoke-RestMethod -Uri $FullUrl -Method Get -Headers $ApiHeaders -ErrorAction Stop
        Write-Host "SUCCESS! Found Swagger docs at: $endpoint" -ForegroundColor Green
        
        # Save the documentation
        $Response | ConvertTo-Json -Depth 10 | Out-File -FilePath "vea_swagger.json" -Encoding UTF8
        Write-Host "Documentation saved to vea_swagger.json" -ForegroundColor Yellow
        
        # Show endpoints from the swagger doc
        if ($Response.paths) {
            Write-Host "`nAvailable Endpoints:" -ForegroundColor Cyan
            $Response.paths.PSObject.Properties | ForEach-Object {
                $path = $_.Name
                $methods = $_.Value.PSObject.Properties.Name -join ", "
                Write-Host "  $path [$methods]" -ForegroundColor White
            }
        }
        break
    }
    catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Also try to access the documentation page source to extract endpoint info
Write-Host "`nTrying to extract endpoints from documentation page..." -ForegroundColor Cyan

try {
    $DocResponse = Invoke-WebRequest -Uri "$ApiBaseUrl/api-docs" -Method Get
    $DocContent = $DocResponse.Content
    
    # Look for swagger configuration
    if ($DocContent -match 'url:\s*[''"]([^''"]+)[''"]') {
        $SwaggerUrl = $matches[1]
        Write-Host "Found Swagger URL reference: $SwaggerUrl" -ForegroundColor Yellow
        
        # Try to access this URL
        if ($SwaggerUrl -notmatch '^https?://') {
            $SwaggerUrl = "$ApiBaseUrl/$($SwaggerUrl.TrimStart('/'))"
        }
        
        try {
            $SwaggerResponse = Invoke-RestMethod -Uri $SwaggerUrl -Method Get -Headers $ApiHeaders
            Write-Host "Successfully retrieved Swagger from: $SwaggerUrl" -ForegroundColor Green
            $SwaggerResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath "vea_swagger_found.json" -Encoding UTF8
            
            if ($SwaggerResponse.paths) {
                Write-Host "`nAPI Endpoints:" -ForegroundColor Green
                $SwaggerResponse.paths.PSObject.Properties | ForEach-Object {
                    Write-Host "  $($_.Name)" -ForegroundColor White
                }
            }
        }
        catch {
            Write-Host "Failed to retrieve Swagger from URL: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "Failed to analyze documentation page: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nDocumentation search complete" -ForegroundColor Green