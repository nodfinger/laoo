[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$ApiUrl,

    [ValidateNotNullOrEmpty()]
    [string]$ProjectCode = 'LAOO'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$appPath = Join-Path $workspaceRoot 'laoo'
$publishRoot = Join-Path $workspaceRoot 'publish'

Push-Location $appPath
try {
    flutter build apk --release `
        --dart-define="API_URL=$($ApiUrl.TrimEnd('/'))" `
        --dart-define="PROJECT_CODE=$ProjectCode"
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter APK build failed.'
    }
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Path $publishRoot -Force | Out-Null
$sourceApk = Join-Path $appPath 'build\app\outputs\flutter-apk\app-release.apk'
$targetApk = Join-Path $publishRoot "laoo-$ProjectCode-test.apk"
Copy-Item -LiteralPath $sourceApk -Destination $targetApk -Force
Write-Warning 'This test APK currently uses the Android debug signing key. Configure a private release keystore before store distribution.'
Write-Host "Test APK: $targetApk"
