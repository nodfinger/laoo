param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('service', 'meeting', 'visitor', 'time', 'training')]
    [string]$Module,

    [ValidateSet('center-service', 'business', 'meeting', 'visitor', 'time', 'training')]
    [string]$Role,

    [string]$BaseRef = 'origin/main'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$machineConfig = $null
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
}
elseif ($Role -eq 'business') {
    $machineConfigPath = Join-Path $repoRoot 'local.machine.json'
    if (-not (Test-Path $machineConfigPath)) {
        throw "Machine role 'business' requires local.machine.json with ownedModules."
    }
    $machineConfig = Get-Content $machineConfigPath -Raw | ConvertFrom-Json
}

$validRoles = @('center-service', 'business', 'meeting', 'visitor', 'time', 'training')
if ($Role -notin $validRoles) {
    throw "Invalid machine role '$Role'. Expected: $($validRoles -join ', ')."
}

if ($Role -eq 'center-service') {
    Write-Host "MACHINE BOUNDARY PASSED: $Role may verify Core integration and module '$Module'."
    return
}

$ownedRoleByModule = @{
    meeting = 'meeting'
    visitor = 'visitor'
    time = 'time'
    training = 'training'
}

$ownedModules = @()
if ($null -ne $machineConfig -and $null -ne $machineConfig.PSObject.Properties['ownedModules']) {
    $ownedModules = @($machineConfig.ownedModules | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } | Where-Object { $_ })
}

if ($ownedModules.Count -eq 0) {
    if ($Role -eq 'business') {
        throw "Machine role 'business' requires a non-empty ownedModules array in local.machine.json."
    }
    $ownedModules = @($ownedRoleByModule[$Role])
}

$unknownModules = @($ownedModules | Where-Object { $_ -notin $ownedRoleByModule.Keys } | Sort-Object -Unique)
if ($unknownModules.Count -gt 0) {
    throw "local.machine.json contains unsupported ownedModules: $($unknownModules -join ', '). Bootstrap the Project before assigning it to a machine."
}

if ($Module -notin $ownedModules) {
    throw "Machine role '$Role' does not own module '$Module'. ownedModules: $($ownedModules -join ', ')."
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
        throw "Machine role '$Role' has changes outside '$ownedPrefix' while verifying module '$Module'. Keep one Project per PR; split Core Impact into a Center-owned PR:`n - $details"
    }
}
finally {
    Pop-Location
}

Write-Host "MACHINE BOUNDARY PASSED: $Role owns $($ownedModules -join ', ') and changes for module '$Module' are contained in $ownedPrefix."
