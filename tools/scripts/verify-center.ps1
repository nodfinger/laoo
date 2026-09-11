param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('service', 'meeting', 'visitor', 'time')]
    [string]$Module
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Invoke-Checked {
    param([string]$Label, [scriptblock]$Command)
    Write-Host "[$Label]"
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE" }
}

Push-Location $repoRoot
try {
    Invoke-Checked 'Git diff check' { git diff --check }
    Invoke-Checked 'Center-only host guard' {
        $legacyHosts = @(
            'projects\service\laoo_service_api',
            'projects\meeting\laoo_meeting_api',
            'projects\visitor\laoo_visitor_api',
            'projects\time\laoo_time_api',
            'projects\service\lib\main.dart',
            'projects\meeting\lib\main.dart',
            'projects\visitor\lib\main.dart',
            'projects\time\lib\main.dart'
        ) | Where-Object { Test-Path (Join-Path $repoRoot $_) }
        if ($legacyHosts.Count -gt 0) {
            throw "Standalone hosts are not allowed: $($legacyHosts -join ', ')"
        }
    }
    Invoke-Checked 'Center Flutter analyze' { flutter analyze --no-fatal-warnings --no-fatal-infos }
    Invoke-Checked 'Center Flutter test' { flutter test }
    Invoke-Checked 'Center API Release build' { dotnet build .\laoo_api\laoo_api.csproj -c Release }

    $moduleRoot = Join-Path $repoRoot "projects\$Module"
    Push-Location $moduleRoot
    try {
        Invoke-Checked "$Module Flutter analyze" { flutter analyze --no-fatal-warnings --no-fatal-infos }
        Invoke-Checked "$Module Flutter test" { flutter test }
    }
    finally { Pop-Location }

    $apiModule = switch ($Module) {
        'service' { 'projects\service\packages\dotnet\Laoo.Service.Module\Laoo.Service.Module.csproj' }
        'meeting' { 'projects\meeting\packages\dotnet\Laoo.Meeting.Module\Laoo.Meeting.Module.csproj' }
        'visitor' { 'projects\visitor\packages\dotnet\Laoo.Visitor.Module\Laoo.Visitor.Module.csproj' }
        'time' { 'projects\time\packages\dotnet\Laoo.Time.Module\Laoo.Time.Module.csproj' }
    }
    Invoke-Checked "$Module API module Release build" { dotnet build $apiModule -c Release }
}
finally { Pop-Location }

Write-Host "CENTER VERIFY PASSED: $Module"
