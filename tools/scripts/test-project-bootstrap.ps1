param(
    [ValidateSet('service', 'meeting', 'visitor', 'time', 'training', 'gate_pass', 'five_s', 'survey', 'expense', 'project', 'intranet', 'vote', 'pos', 'sales', 'evaluation', 'knowledge', 'memo', 'provider', 'booking', 'digital_checklist', 'document_control', 'market', 'patrol', 'pet', 'rental', 'school', 'school_food', 'site', 'sport', 'sap_pms')]
    [string]$Project,

    [switch]$AllProjects
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

if ($AllProjects) {
    $projectsRoot = Join-Path $repoRoot 'projects'
    $projects = Get-ChildItem $projectsRoot -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName 'pubspec.yaml')) -and
        (Test-Path (Join-Path $_.FullName ('lib\' + $_.Name + '_feature.dart'))) -and
        (Test-Path (Join-Path $_.FullName ('lib\features\' + $_.Name + '\' + $_.Name + '_feature_host.dart'))) -and
        (Test-Path (Join-Path $_.FullName ('lib\features\' + $_.Name + '\' + $_.Name + '_route_contract.dart'))) -and
        (Test-Path (Join-Path $_.FullName ('lib\features\' + $_.Name + '\' + $_.Name + '_go_routes.dart')))
    }
    $failed = @()
    foreach ($candidate in $projects) {
        & $PSCommandPath -Project $candidate.Name
        if ($LASTEXITCODE -ne 0) { $failed += $candidate.Name }
    }
    if ($failed.Count -gt 0) { throw "Project bootstrap validation failed: $($failed -join ', ')" }
    Write-Host "PROJECT BOOTSTRAP PASSED: $($projects.Count) projects."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Project)) {
    throw 'Specify -Project <name> or use -AllProjects.'
}
$projectPascal = (($Project -split '[_-]' | ForEach-Object {
    (Get-Culture).TextInfo.ToTitleCase($_)
}) -join '')
$packageName = 'laoo_' + $Project
$featureDirectory = Join-Path $repoRoot ('projects\' + $Project + '\lib\features\' + $Project)
$rootRouterPath = Join-Path $repoRoot 'lib\app\router\app_router.dart'

$packageRoot = Join-Path $repoRoot ('projects\' + $Project)
$entryPoint = Join-Path $packageRoot ('lib\' + $Project + '_feature.dart')
$featureHost = Join-Path $featureDirectory ($Project + '_feature_host.dart')
$routeContract = Join-Path $featureDirectory ($Project + '_route_contract.dart')
$routeBuilder = Join-Path $featureDirectory ($Project + '_go_routes.dart')
# Required files are validated below.
$valid = Test-Path $entryPoint
$valid = $valid -and (Test-Path (Join-Path $packageRoot 'pubspec.yaml'))
$valid = $valid -and (Test-Path $featureHost)
$valid = $valid -and (Test-Path $routeContract)
$valid = $valid -and (Test-Path $routeBuilder)
$valid = $valid -and (Select-String -Path $entryPoint -Pattern ($Project + '_feature_host\.dart') -Quiet)
$valid = $valid -and (Select-String -Path $entryPoint -Pattern ($Project + '_route_contract\.dart') -Quiet)
$valid = $valid -and (Select-String -Path $entryPoint -Pattern ($Project + '_go_routes\.dart') -Quiet)
$valid = $valid -and (Select-String -Path $featureHost -Pattern ('configure' + $projectPascal + 'FeatureHost') -Quiet)
$valid = $valid -and (Select-String -Path $routeBuilder -Pattern ('build' + $projectPascal + 'FeatureRoutes') -Quiet)
$valid = $valid -and (Select-String -Path (Join-Path $repoRoot 'pubspec.yaml') -Pattern ('^\s*' + $packageName + '\s*:') -Quiet)

$router = Get-Content $rootRouterPath -Raw
$builderCount = [regex]::Matches($router, ('build' + $projectPascal + 'FeatureRoutes\s*\(')).Count
$valid = $valid -and $builderCount -eq 1
$hasRootPlaceholder = $router.Contains('RoutePaths.' + $Project)
$hasRootPlaceholder = $hasRootPlaceholder -or ($Project -eq 'time' -and ($router.Contains('RoutePaths.myTime') -or $router.Contains('RoutePaths.myAttendance') -or $router.Contains('RoutePaths.myLeave')))
$valid = $valid -and -not $hasRootPlaceholder
echo $valid
exit (-not $valid)
