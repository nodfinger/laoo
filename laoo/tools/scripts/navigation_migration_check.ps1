$ErrorActionPreference = "Stop"

$projectRoot = "C:\laoo\laoo"
$libRoot = Join-Path $projectRoot "lib"

Write-Host ""
Write-Host "Laoo Navigation Migration Check" -ForegroundColor Cyan
Write-Host "Project: $projectRoot"
Write-Host ""

if (-not (Test-Path (Join-Path $projectRoot "pubspec.yaml"))) {
    throw "ไม่พบ pubspec.yaml ที่ $projectRoot"
}

$patterns = @(
    "LaooApp\.loginRoute",
    "LaooApp\.landingRoute",
    "LaooApp\.homeRoute",
    "Navigator\.pushNamed",
    "Navigator\.pushNamedAndRemoveUntil"
)

$foundAny = $false

foreach ($pattern in $patterns) {
    $matches = Get-ChildItem $libRoot -Recurse -Filter *.dart |
        Select-String -Pattern $pattern

    if ($matches) {
        $foundAny = $true
        Write-Host "พบ Legacy Pattern: $pattern" -ForegroundColor Yellow
        $matches | ForEach-Object {
            Write-Host ("  {0}:{1}  {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim())
        }
        Write-Host ""
    }
}

if (-not $foundAny) {
    Write-Host "ไม่พบ Legacy named-route navigation ใน lib/" -ForegroundColor Green
}

Write-Host ""
Write-Host "กำลังรัน flutter analyze..." -ForegroundColor Cyan
Push-Location $projectRoot
try {
    flutter analyze
}
finally {
    Pop-Location
}
