param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('service', 'meeting', 'visitor', 'time', 'training', 'gate_pass', 'five_s', 'survey', 'expense', 'project', 'intranet', 'vote', 'pos', 'sales', 'evaluation')]
    [string]$Module,

    [ValidateSet('core', 'business', 'center-service', 'meeting', 'visitor', 'time', 'training', 'gate_pass', 'five_s', 'survey', 'expense', 'project', 'intranet', 'vote', 'pos', 'sales', 'evaluation')]
    [string]$Role,

    [string]$BaseRef = 'origin/main'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

if ([string]::IsNullOrWhiteSpace($Role)) {
    $machineConfigPath = Join-Path $repoRoot 'local.machine.json'
    if (-not (Test-Path $machineConfigPath)) {
        if ([string]::Equals($env:CI, 'true', [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning 'local.machine.json not found in CI; machine boundary check skipped. CI must rely on PR ownership review.'
            return
        }
        throw 'local.machine.json not found. Copy local.machine.example.json and set the machine role before verification.'
    }

    $machineConfig = Get-Content $machineConfigPath -Raw | ConvertFrom-Json
    $Role = [string]$machineConfig.role
    $ownedModules = @($machineConfig.ownedModules | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$validRoles = @('core', 'business', 'center-service', 'meeting', 'visitor', 'time', 'training', 'gate_pass', 'five_s', 'survey', 'expense', 'project', 'intranet', 'vote', 'pos', 'sales', 'evaluation')
if ($Role -notin $validRoles) {
    throw "Invalid machine role '$Role'. Expected: $($validRoles -join ', ')."
}

if ($Role -in @('core', 'center-service')) {
    Write-Host "MACHINE BOUNDARY PASSED: $Role may verify Core integration and module '$Module'."
    return
}

if ($Role -eq 'business') {
    if ($ownedModules.Count -eq 0) { throw "Machine role 'business' requires non-empty ownedModules in local.machine.json." }
    if ($Module -notin $ownedModules) { throw "Machine role 'business' cannot verify module '$Module'. Owned modules: $($ownedModules -join ', ')." }
}

$ownedRoleByModule = @{
    meeting = 'meeting'
    visitor = 'visitor'
    time = 'time'
    training = 'training'
    gate_pass = 'gate_pass'
    five_s = 'five_s'
    survey = 'survey'
    expense = 'expense'
    project = 'project'
    intranet = 'intranet'
    vote = 'vote'
    pos = 'pos'
    sales = 'sales'
    evaluation = 'evaluation'
}

if ($Role -ne 'business' -and $Role -ne $ownedRoleByModule[$Module]) {
    throw "Machine role '$Role' cannot verify module '$Module'. Use the owned module or move integration work to the Center machine."
}

Push-Location $repoRoot
try {
    $changed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $baseExists = $null -ne (git rev-parse --verify --quiet $BaseRef)
    if ($LASTEXITCODE -eq 0 -and $baseExists) {
        git diff --name-only --diff-filter=ACMRTUXB "$BaseRef...HEAD" |
            ForEach-Object { if ($_){ [void]$changed.Add($_.Replace('\', '/')) } }
    }

    git diff --name-only --diff-filter=ACMRTUXB |
        ForEach-Object { if ($_){ [void]$changed.Add($_.Replace('\', '/')) } }
    git diff --cached --name-only --diff-filter=ACMRTUXB |
        ForEach-Object { if ($_){ [void]$changed.Add($_.Replace('\', '/')) } }
    git ls-files --others --exclude-standard |
        ForEach-Object { if ($_){ [void]$changed.Add($_.Replace('\', '/')) } }

    $ownedPrefix = "projects/$Module/"
    $outsideOwnership = @($changed | Where-Object { -not $_.StartsWith($ownedPrefix, [System.StringComparison]::OrdinalIgnoreCase) } | Sort-Object)
    if ($outsideOwnership.Count -gt 0) {
        $details = $outsideOwnership -join "`n - "
        throw "Machine role '$Role' has changes outside '$ownedPrefix' while verifying module '$Module'. Split Core Impact into a Center-owned PR:`n - $details"
    }
}
finally {
    Pop-Location
}

Write-Host "MACHINE BOUNDARY PASSED: $Role changes for module '$Module' are contained in $ownedPrefix."
