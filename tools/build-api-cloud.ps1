[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $workspaceRoot 'laoo_api\laoo_api.csproj'
$publishRoot = Join-Path $workspaceRoot 'publish'
$publishPath = Join-Path $publishRoot 'laoo_api_cloud'
$zipPath = Join-Path $publishRoot 'laoo_api_cloud.zip'

New-Item -ItemType Directory -Path $publishRoot -Force | Out-Null
if (Test-Path -LiteralPath $publishPath) {
    Remove-Item -LiteralPath $publishPath -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

dotnet publish $projectPath -c Release -o $publishPath
if ($LASTEXITCODE -ne 0) {
    throw 'dotnet publish failed.'
}

$forbidden = Get-ChildItem -LiteralPath $publishPath -Recurse -File |
    Where-Object { $_.Name -in @('local.json', 'appsettings.Local.json') }
if ($forbidden) {
    throw "Publish contains forbidden local configuration: $($forbidden.FullName -join ', ')"
}

Compress-Archive -Path (Join-Path $publishPath '*') -DestinationPath $zipPath
Write-Host "Cloud package: $zipPath"
