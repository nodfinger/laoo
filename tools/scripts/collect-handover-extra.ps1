$ErrorActionPreference='Stop'
$out=Join-Path (Get-Location) 'docs/handover/laoo-pat-20260927'
$source='C:\laooplatform\laoo_service'
$skip='(^|/)(\.git|\.dart_tool|build|bin|obj|node_modules|uploads|tmp|output|backups)(/|$)|generated_plugin|GeneratedPlugin|(^|/)(local[^/]*\.json|appsettings[^/]*\.json|\.env[^/]*)$|\.(dll|pdb|exe|pfx|pem|key|bak|zip|log|http)$'
$secret='-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|(?i);\s*(?:Password|Pwd)\s*=\s*(?!YOUR_PASSWORD|<|\{)[^;\s"<>]{3,}'
$items=@()
$files=@(Get-ChildItem $source -File -Force)
foreach($folder in @('lib','laoo_service_api','docs','test','tools','assets','android','ios','linux','macos','windows','web')){
 $files+=@(Get-ChildItem (Join-Path $source $folder) -File -Recurse -ErrorAction SilentlyContinue)
}
foreach($file in $files){
 $relative=$file.FullName.Substring($source.Length+1).Replace('\','/')
 $state='saved'
 if($relative -match $skip -or $relative -match '(^|/)(ephemeral|\.plugin_symlinks|\.gradle)(/|$)|(^|/)(\.flutter-plugins-dependencies|local\.properties|Generated\.xcconfig|flutter_export_environment\.sh|flutter_\d+\.png|core_dirty_files\.txt|remote_main_files\.txt)$'){$state='excluded'}
 elseif($file.Length -gt 5MB){$state='large-file-separate-transfer'}
 elseif($file.Extension -in @('.cs','.dart','.json','.yaml','.sql','.md','.ps1','.txt') -and [IO.File]::ReadAllText($file.FullName) -match $secret){$state='withheld-credential-review'}
 if($state -eq 'saved'){
  $target=Join-Path $out "legacy-service-unversioned/files/$relative.snapshot"
  [void](New-Item -ItemType Directory -Force -Path (Split-Path $target))
  Copy-Item -LiteralPath $file.FullName -Destination $target
 }
 if($state -ne 'excluded'){$items+=@{path=$relative;status=$state;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash}}
}
$items | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'legacy-service-unversioned.json') -Encoding UTF8
$cfg=Get-Content C:\laooplatform\laoo\laoo_api\local.json -Raw | ConvertFrom-Json
$cn=New-Object Data.SqlClient.SqlConnection $cfg.ConnectionStrings.LaooDatabase
$cn.Open()
try {
 $cmd=$cn.CreateCommand();$cmd.CommandText='SELECT MigrationID,ProjectCode,Checksum,AppliedUtc FROM dbo.TDSTSchemaMigration ORDER BY MigrationID'
 $dt=New-Object Data.DataTable;$adapter=New-Object Data.SqlClient.SqlDataAdapter $cmd;[void]$adapter.Fill($dt)
 $dt | Select-Object MigrationID,ProjectCode,Checksum,AppliedUtc | Export-Csv (Join-Path $out 'migration-ledger.csv') -NoTypeInformation -Encoding UTF8
 $ledger=@{};foreach($r in $dt.Rows){$ledger[$r.MigrationID]=$r.Checksum}
 $migrationFiles=@(Get-ChildItem database/migrations -Filter '*.sql')
 $migrationFiles+=@(Get-ChildItem projects -Directory | ForEach-Object {Get-ChildItem (Join-Path $_.FullName 'database/migrations') -Filter '*.sql' -ErrorAction SilentlyContinue})
 $states=foreach($f in $migrationFiles){
  $id=$f.BaseName;$content=[IO.File]::ReadAllText($f.FullName).Replace("`r`n","`n").Replace("`r","`n")
  $sha=([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-','')
  $status=if(-not $ledger.ContainsKey($id)){'PENDING'}elseif($ledger[$id] -eq $sha){'APPLIED_MATCH'}else{'CHECKSUM_MISMATCH'}
  [PSCustomObject]@{migrationId=$id;status=$status;sourceChecksum=$sha;ledgerChecksum=$ledger[$id]}
 }
 $states | Export-Csv (Join-Path $out 'migration-status.csv') -NoTypeInformation -Encoding UTF8
 $cmd.CommandText='SELECT MenuCode,MenuName,ScreenType,RouteName,RoutePath,IsActive,IsVisible FROM dbo.TDADMainMenu ORDER BY MenuCode'
 $menus=New-Object Data.DataTable;$adapter=New-Object Data.SqlClient.SqlDataAdapter $cmd;[void]$adapter.Fill($menus)
 $menus | Select-Object MenuCode,MenuName,ScreenType,RouteName,RoutePath,IsActive,IsVisible | Export-Csv (Join-Path $out 'menu-metadata.csv') -NoTypeInformation -Encoding UTF8
 Write-Output "Database=$($cn.Database)"; $states | Group-Object status | Select-Object Name,Count
}finally{$cn.Dispose()}
Write-Output "Unversioned source files=$($items.Count)"
