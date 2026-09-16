param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('service', 'meeting', 'visitor', 'time', 'training')]
    [string]$Module,

    [ValidateSet('center-service', 'business', 'meeting', 'visitor', 'time', 'training')]
    [string]$Role
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Invoke-Checked {
    param([string]$Label, [scriptblock]$Command)
    Write-Host "[$Label]"
    & $Command
    if (-not $?) {
        $exitCode = if ($null -eq $LASTEXITCODE) { 'unknown' } else { $LASTEXITCODE }
        throw "$Label failed with exit code $exitCode"
    }
}

Push-Location $repoRoot
try {
    Write-Host '[Machine ownership boundary]'
    $boundaryArguments = @{ Module = $Module }
    if (-not [string]::IsNullOrWhiteSpace($Role)) {
        $boundaryArguments.Role = $Role
    }
    & (Join-Path $PSScriptRoot 'check-machine-boundaries.ps1') @boundaryArguments
    Invoke-Checked 'Center host port configuration' {
        $machineConfigPath = Join-Path $repoRoot 'local.machine.json'
        if (-not (Test-Path $machineConfigPath)) {
            if ([string]::Equals($env:CI, 'true', [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning 'local.machine.json not found in CI; Center host port check skipped.'
                return
            }
            throw 'local.machine.json not found. Copy the appropriate local.machine.*.example.json before verification.'
        }

        $machineConfig = Get-Content $machineConfigPath -Raw | ConvertFrom-Json
        if ([int]$machineConfig.webPort -ne 8080 -or [int]$machineConfig.apiPort -ne 5080) {
            throw 'Center host must use webPort 8080 and apiPort 5080.'
        }
    }
    Invoke-Checked 'Git diff check' { git diff --check }
    Invoke-Checked 'Center-only host guard' {
        $legacyHosts = @(
            'projects\service\laoo_service_api',
            'projects\meeting\laoo_meeting_api',
            'projects\visitor\laoo_visitor_api',
            'projects\time\laoo_time_api',
            'projects\training\laoo_training_api',
            'projects\service\lib\main.dart',
            'projects\meeting\lib\main.dart',
            'projects\visitor\lib\main.dart',
            'projects\time\lib\main.dart',
            'projects\training\lib\main.dart'
        ) | Where-Object { Test-Path (Join-Path $repoRoot $_) }
        if ($legacyHosts.Count -gt 0) {
            throw "Standalone hosts are not allowed: $($legacyHosts -join ', ')"
        }
    }
    Invoke-Checked 'Center Flutter analyze' { flutter analyze --no-fatal-warnings --no-fatal-infos }
    Invoke-Checked 'Center Flutter test' { flutter test }
    Invoke-Checked 'Center API Release build' { dotnet build .\laoo_api\laoo_api.csproj -c Release }

    $moduleRoot = Join-Path $repoRoot "projects\$Module"
    if (Test-Path (Join-Path $moduleRoot 'pubspec.yaml')) {
        Push-Location $moduleRoot
        try {
            Invoke-Checked "$Module Flutter analyze" { flutter analyze --no-fatal-warnings --no-fatal-infos }
            Invoke-Checked "$Module Flutter test" { flutter test }
        }
        finally { Pop-Location }
    }
    else {
        Write-Host "[$Module Flutter checks skipped: no projects/$Module/pubspec.yaml yet]"
    }

    $apiModule = switch ($Module) {
        'service' { 'projects\service\packages\dotnet\Laoo.Service.Module\Laoo.Service.Module.csproj' }
        'meeting' { 'projects\meeting\packages\dotnet\Laoo.Meeting.Module\Laoo.Meeting.Module.csproj' }
        'visitor' { 'projects\visitor\packages\dotnet\Laoo.Visitor.Module\Laoo.Visitor.Module.csproj' }
        'time' { 'projects\time\packages\dotnet\Laoo.Time.Module\Laoo.Time.Module.csproj' }
        'training' { 'projects\training\packages\dotnet\Laoo.Training.Module\Laoo.Training.Module.csproj' }
    }
    Invoke-Checked "$Module API module Release build" { dotnet build $apiModule -c Release }
}
finally { Pop-Location }

Write-Host "CENTER VERIFY PASSED: $Module"
