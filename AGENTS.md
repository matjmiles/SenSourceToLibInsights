# Agent Guidelines for VEA Springshare API Repository

## Build/Lint/Test Commands

### Main Pipeline Execution
- **Full pipeline**: `run_export.bat` (runs complete VEA data extraction and CSV conversion)
- **Setup**: `setup.bat` (creates config.ps1 from template)

### PowerShell Script Execution
- **Individual sensor extraction**: `powershell -ExecutionPolicy Bypass -File "scripts\VEA-Zone-Extractor.ps1" -StartDate "2025-12-01T00:00:00Z" -EndDate "2025-12-07T23:59:59Z"`
- **CSV conversion**: `powershell -ExecutionPolicy Bypass -File "scripts\VEA-Generate-All-Individual-CSVs.ps1" -GateMethod "Bidirectional"`

### Credential Management
- **Interactive setup**: `setup.bat` (prompts for credentials)
- **Automated setup**: `powershell -ExecutionPolicy Bypass -File "scripts\setup-automated.ps1" -ClientId "id" -ClientSecret "secret" -UseEnvironmentVariables`
- **Reset credentials**: `powershell -ExecutionPolicy Bypass -File "scripts\setup-automated.ps1" -ResetCredentials`

### Testing Single Components
- **API authentication test**: `powershell -ExecutionPolicy Bypass -File "archive\vea_auth_test.ps1"`
- **Data extraction test**: `powershell -ExecutionPolicy Bypass -File "archive\vea_clean_test.ps1"`
- **Credential verification**: `powershell -ExecutionPolicy Bypass -File "scripts\test-credentials-simple.ps1"`

## Code Style Guidelines

### PowerShell Conventions
- **Variables**: Use `$camelCase` for local variables (e.g., `$accessToken`, `$zoneData`)
- **Functions**: Use `PascalCase` for function names (e.g., `Get-VEAAccessToken`, `ConvertTo-CSV`)
- **Parameters**: Define with `param()` blocks, use `[string]`, `[int]` type hints
- **Comments**: Use `#` for single-line comments explaining complex logic
- **Error Handling**: Use `try/catch` blocks with `Write-Error` for failures
- **Indentation**: 4 spaces consistently throughout scripts

### Naming Conventions
- **Files**: PascalCase with descriptive names (e.g., `VEA-Zone-Extractor.ps1`)
- **API endpoints**: Use consistent URL construction with `$ApiBaseUrl`
- **Output files**: Use `{SensorName}_{type}_data.{ext}` pattern
- **Configuration**: Centralize in `config.ps1` with clear variable names

### Imports and Dependencies
- **Modules**: No external PowerShell modules required - uses only built-in cmdlets
- **Configuration**: Load via `. $ConfigPath` pattern in scripts
- **API calls**: Use `Invoke-RestMethod` with consistent header patterns

### Data Handling
- **JSON processing**: Use `ConvertFrom-Json`/`ConvertTo-Json` with appropriate depth
- **CSV export**: Use `Export-Csv -NoTypeInformation -Encoding UTF8`
- **Date formats**: ISO-8601 for API calls, YYYY-MM-DD for Springshare CSV
- **Encoding**: UTF-8 without BOM for all file outputs

### Error Handling and Logging
- **Validation**: Check file existence with `Test-Path` before operations
- **User feedback**: Use `Write-Host -ForegroundColor` for status messages
- **API errors**: Catch exceptions and provide meaningful error messages
- **Progress tracking**: Show counters and percentages for batch operations</content>
<parameter name="filePath">C:\Users\milesm\Documents\repos\vea springshare api\AGENTS.md