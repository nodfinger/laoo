$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# Use the machine's local time: year, month, day, hour, minute, second.
$buildVersion = Get-Date -Format 'yyMMdd-HHmmss'
Push-Location $repoRoot
try {
    & flutter build web --release --no-pub "--dart-define=LAOO_BUILD_VERSION=$buildVersion"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Login build version: $buildVersion"
}
finally {
    Pop-Location
}
