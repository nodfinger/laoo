$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$boundaryScript = Get-Content (Join-Path $PSScriptRoot 'check-machine-boundaries.ps1') -Raw
Assert-True ($boundaryScript -match "'business'") 'Boundary script must support the business role.'
Assert-True ($boundaryScript -match 'ownedModules') 'Boundary script must read ownedModules.'
Assert-True ($boundaryScript -match 'Keep one Project per PR') 'Boundary script must keep a Project PR scoped to one module.'

$meetingConfig = Get-Content (Join-Path $repoRoot 'local.machine.meeting-training.example.json') -Raw | ConvertFrom-Json
Assert-True ($meetingConfig.role -eq 'business') 'Meeting example must use the business role.'
Assert-True (@($meetingConfig.ownedModules).Count -eq 3) 'Meeting example must declare three owned modules.'
Assert-True (@($meetingConfig.ownedModules) -contains 'meeting') 'Meeting example must own meeting.'
Assert-True (@($meetingConfig.ownedModules) -contains 'visitor') 'Meeting example must own visitor.'
Assert-True (@($meetingConfig.ownedModules) -contains 'training') 'Meeting example must own training.'

Write-Host 'MACHINE BOUNDARY CONFIG TEST PASSED'
