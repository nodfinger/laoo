$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$buildVersion = Get-Date -Format 'yyMMdd-HHmmss'
Push-Location $repoRoot
try {
    Write-Host "Login build version: V. $buildVersion"
    & flutter run -d web-server --no-pub --web-port 8080 --web-hostname 127.0.0.1 --dart-define=API_URL=http://localhost:5080 --dart-define=PROJECT_CODE=LAOO "--dart-define=LAOO_BUILD_VERSION=$buildVersion"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}
