param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('service', 'meeting', 'visitor', 'time', 'training', 'gate_pass', 'five_s', 'survey', 'expense', 'project', 'intranet', 'vote')]
    [string]$Project
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
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
