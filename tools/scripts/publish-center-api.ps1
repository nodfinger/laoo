param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $repoRoot "artifacts\center-api-$stamp"
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

dotnet publish (Join-Path $repoRoot 'laoo_api\laoo_api.csproj') `
    -c Release `
    -o $outputFullPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$requiredFiles = @(
    'laoo_api.exe',
    'Laoo.Service.Module.dll',
    'Laoo.Meeting.Module.dll',
    'Laoo.Visitor.Module.dll'
)
foreach ($file in $requiredFiles) {
    if (-not (Test-Path (Join-Path $outputFullPath $file))) {
        throw "Center publish is missing $file"
    }
}

$forbiddenFiles = @('local.json', 'appsettings.Local.json')
foreach ($file in $forbiddenFiles) {
    if (Test-Path (Join-Path $outputFullPath $file)) {
        throw "Center publish contains forbidden local configuration: $file"
    }
}

Write-Host "CENTER API PUBLISH PASSED: $outputFullPath"
