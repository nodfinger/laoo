param([string]$OutputDirectory = (Join-Path $env:TEMP 'laoo-completion-audit'))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
# Read-only inventory. No credentials or business records are exported.
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$menus = @()
try {
    $db.Open()
    $q = $db.CreateCommand()
    $q.CommandText = @"
SELECT P.ProjectCode,M.MenuCode,M.MenuName,M.ScreenType,M.RouteName,
M.IsActive MenuActive,M.IsVisible MenuVisible,PM.IsActive MappingActive,P.IsActive ProjectActive,
(SELECT COUNT(*) FROM dbo.TDADPermission X WHERE X.ProjectID=P.ProjectID AND X.ScreenCode=M.MenuCode AND X.IsActive=1) PermissionDefinitions
FROM dbo.TDADProject P JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID
JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode ORDER BY P.ProjectCode,M.MenuCode;
"@
    $r=$q.ExecuteReader()
    while($r.Read()) {
        $row=[ordered]@{}
        for($i=0;$i -lt $r.FieldCount;$i++) { $row[$r.GetName($i)]=if($r.IsDBNull($i)){$null}else{$r.GetValue($i)} }
        $row['Status']=if($row.MenuCode -eq '14003'){'RETIRED'}else{'NOT_TESTED'}
        $menus += [pscustomobject]$row
    }
    $r.Close()
} finally { $db.Dispose() }
$trees=@()
foreach($line in (& git -C $root worktree list --porcelain)) {
    if($line.StartsWith('worktree ')) {
        $path=$line.Substring(9)
        $trees += [pscustomobject]@{Path=$path;Exists=(Test-Path -LiteralPath $path);Changes=$(if(Test-Path -LiteralPath $path){@(& git -C $path status --short)}else{@()})}
    }
}
$handover=@()
foreach($ref in (& git -C $root for-each-ref '--format=%(refname)' refs/heads/handover refs/remotes/origin/handover)) {
    & git -C $root merge-base --is-ancestor $ref HEAD
    $ancestor=$LASTEXITCODE -eq 0
    $handover += [pscustomobject]@{Ref=$ref;Ancestor=$ancestor;TreeDifferences=@(& git -C $root diff --name-status HEAD $ref)}
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$result=[ordered]@{GeneratedAtUtc=[DateTime]::UtcNow.ToString('o');Head=(& git -C $root rev-parse HEAD);Menus=$menus;Worktrees=$trees;Handover=$handover;Runtime='NOT_TESTED';DatabaseWrites=$false;Caution='Metadata and tree differences are not workflow evidence or proof of missing handover work.'}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'inventory.json') -Encoding UTF8
Write-Output ('Inventory: '+(Join-Path $OutputDirectory 'inventory.json'))
Write-Output ('Mappings: '+$menus.Count+'; worktrees: '+$trees.Count+'; handover refs: '+$handover.Count)
$report = @('# LAOO menu completion inventory', '', 'Database metadata only. NOT_TESTED is not a failure or a passing workflow. Permission counts are definitions, not effective user permissions.', '', '| Project | MenuCode | MenuName | ScreenType | RouteName | Menu active/visible | Mapping active | Permission definitions | Status |', '|---|---|---|---:|---|---|---|---:|---|')
foreach($menu in $menus) {
    $name=([string]$menu.MenuName).Replace('|','/').Replace("`n",' ')
    $report += ('| {0} | {1} | {2} | {3} | {4} | {5}/{6} | {7} | {8} | {9} |' -f $menu.ProjectCode,$menu.MenuCode,$name,$menu.ScreenType,$menu.RouteName,$menu.MenuActive,$menu.MenuVisible,$menu.MappingActive,$menu.PermissionDefinitions,$menu.Status)
}
$report | Set-Content -LiteralPath (Join-Path $OutputDirectory 'menu-checklist.md') -Encoding UTF8
