param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('core', 'service', 'meeting', 'visitor', 'time', 'training', 'gate_pass', 'five_s', 'survey', 'expense', 'project', 'document_control', 'knowledge', 'memo', 'provider', 'school', 'school_food', 'sport', 'patrol', 'intranet', 'vote', 'pos', 'sales', 'evaluation', 'digital_checklist', 'market')]
    [string]$Module,
    [string]$MigrationId,
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
    document_control = 'LAOO_DOCUMENT'
    knowledge = 'LAOO_KNOWLEDGE'
    memo = 'LAOO_MEMO'
    provider = 'LAOO_PROVIDER'
    school = 'LAOO_SCHOOL'
    school_food = 'LAOO_SCHOOL_FOOD'
    sport = 'LAOO_SPORT'
    patrol = 'LAOO_PATROL'
    intranet = 'LAOO_INTRANET'
    vote = 'LAOO_VOTE'
    pos = 'LAOO_POS'
    sales = 'LAOO_SALES'
    evaluation = 'LAOO_EVALUATION'
    digital_checklist = 'LAOO_DIGITAL_CHECKLIST'
    market = 'LAOO_MARKET'
}
$arguments = @(
    'run',
    '--project', (Join-Path $repoRoot 'tools\migrations\Laoo.MigrationRunner\Laoo.MigrationRunner.csproj'),
    '--',
    '--root', $repoRoot,
    '--project', $projectCodes[$Module]
)
if ($DryRun) { $arguments += '--dry-run' }
if ($MigrationId) { $arguments += @('--migration', $MigrationId) }

& dotnet @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
