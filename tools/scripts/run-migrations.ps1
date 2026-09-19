param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('core', 'service', 'meeting', 'visitor', 'time', 'training', 'gate_pass', 'five_s', 'survey', 'expense', 'project', 'intranet', 'vote', 'sales')]
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
    five_s = 'LAOO_5S'
    survey = 'LAOO_SURVEY'
    expense = 'LAOO_EXPENSE'
    project = 'LAOO_PROJECT'
    intranet = 'LAOO_INTRANET'
    vote = 'LAOO_VOTE'
    sales = 'LAOO_SALES'
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
