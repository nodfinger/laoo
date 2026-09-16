param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('core', 'service', 'meeting', 'visitor', 'time', 'training', 'gate_pass')]
    [string]$Module,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$projectCodes = @{
    core = 'LAOO'
    service = 'LAOO_SERVICE'
    meeting = 'LAOO_MEETING'
    visitor = 'LAOO_VISITOR'
    time = 'LAOO_TIME'
    training = 'LAOO_TRAINING'
    gate_pass = 'LAOO_GATE_PASS'
}
$arguments = @(
    'run',
    '--project', (Join-Path $repoRoot 'tools\migrations\Laoo.MigrationRunner\Laoo.MigrationRunner.csproj'),
    '--',
    '--root', $repoRoot,
    '--project', $projectCodes[$Module]
)
if ($DryRun) { $arguments += '--dry-run' }

& dotnet @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
