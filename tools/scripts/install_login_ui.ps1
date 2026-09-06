$ErrorActionPreference = "Stop"

$SourceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ProjectRoot = "C:\laooplatformplatform\laoo"

Write-Host "Installing Laoo Login UI..." -ForegroundColor Green

$Folders = @(
    "$ProjectRoot\assets\images",
    "$ProjectRoot\lib\core\theme",
    "$ProjectRoot\lib\features\authentication\presentation\pages",
    "$ProjectRoot\lib\features\authentication\presentation\widgets"
)

foreach ($Folder in $Folders) {
    New-Item -ItemType Directory -Force -Path $Folder | Out-Null
}

Copy-Item "$SourceRoot\assets\images\laoo_login_logo.png" `
    "$ProjectRoot\assets\images\laoo_login_logo.png" -Force

Copy-Item "$SourceRoot\lib\main.dart" `
    "$ProjectRoot\lib\main.dart" -Force

Copy-Item "$SourceRoot\lib\core\theme\app_theme.dart" `
    "$ProjectRoot\lib\core\theme\app_theme.dart" -Force

Copy-Item "$SourceRoot\lib\features\authentication\presentation\pages\login_page.dart" `
    "$ProjectRoot\lib\features\authentication\presentation\pages\login_page.dart" -Force

Copy-Item "$SourceRoot\lib\features\authentication\presentation\widgets\login_form.dart" `
    "$ProjectRoot\lib\features\authentication\presentation\widgets\login_form.dart" -Force

Write-Host ""
Write-Host "Files copied successfully." -ForegroundColor Green
Write-Host "Please add the asset entry from pubspec_asset_snippet.yaml to pubspec.yaml."
Write-Host ""
Write-Host "Then run:" -ForegroundColor Cyan
Write-Host "  cd C:\laooplatformplatform\laoo"
Write-Host "  flutter pub get"
Write-Host "  flutter run -d windows"
