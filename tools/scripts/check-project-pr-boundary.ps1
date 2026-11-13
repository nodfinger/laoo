param(
    [string]$BaseRef = 'origin/main',
    [string]$HeadRef = 'HEAD',
    [string]$Project = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($BaseRef)) { $BaseRef = 'origin/main' }
if ([string]::IsNullOrWhiteSpace($HeadRef)) { $HeadRef = 'HEAD' }
Push-Location $repoRoot
try {
    $changed = @(git diff --name-only --diff-filter=ACMRTUXB "$BaseRef...$HeadRef" | ForEach-Object { $_.Replace('\', '/') } | Where-Object { $_ })
    if ($changed.Count -eq 0) {
        Write-Host 'No changed files found for the requested range.'
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($Project)) {
        $branch = (git symbolic-ref --short HEAD 2>$null)
        if ($branch -match '^(?<name>[A-Za-z0-9-]+)/(feature|fix|bugfix|chore|refactor|docs)/') {
            $Project = $Matches.name
        }
    }

    $projectPaths = @($changed | Where-Object { $_ -match '^projects/([^/]+)/' })
    $rootPaths = @($changed | Where-Object { $_ -notmatch '^projects/[^/]+/' })

    if ([string]::IsNullOrWhiteSpace($Project)) {
        if ($projectPaths.Count -gt 0) {
            $projects = @($projectPaths | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique)
            if ($projects.Count -ne 1) {
                throw "Project PR must target exactly one project. Found: $($projects -join ', ')."
            }
            $Project = $projects[0]
        }
    }

    if ([string]::IsNullOrWhiteSpace($Project)) {
        Write-Host 'Core/infrastructure change detected; project boundary restriction is not applied.'
        exit 0
    }

    $projectPrefix = "projects/$Project/"
    $outside = @($changed | Where-Object { -not $_.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase) })
    if ($outside.Count -gt 0) {
        throw "Project PR '$Project' changes files outside '$projectPrefix':`n - $($outside -join "`n - ")`nSplit Core/Shared/Root changes into a separate compatible Core PR."
    }

    $migrationFiles = @($changed | Where-Object { $_ -match "^projects/$([regex]::Escape($Project))/.*database/migrations/.*\.sql$" })
    foreach ($file in $migrationFiles) {
        $name = [IO.Path]::GetFileName($file)
        if ($name -notmatch '^\d{14}_[A-Z0-9]+_.+\.sql$') {
            throw "Migration '$file' must use yyyyMMddHHmmss_PROJECTCODE_description.sql."
        }
    }

    Write-Host "PROJECT BOUNDARY PASSED: $Project ($($changed.Count) files)."
}
finally {
    Pop-Location
}
