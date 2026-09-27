param([string]$Destination='C:\laooplatform\laoo_service\handover-laoo-pat-20260927')
$ErrorActionPreference='Stop'
$root='C:\laooplatform\laoo'
$out=Join-Path $Destination 'docs/handover/laoo-pat-20260927'
[void](New-Item -ItemType Directory -Force -Path $out)
$excluded='(^|/)(\.git|\.dart_tool|build|bin|obj|node_modules|uploads|tmp|output|backups|failures|api-build-check[^/]*|\.tmp[^/]*|\.artifacts|\.buildcheck|build_artifacts)(/|$)|generated_plugin|GeneratedPlugin|(^|/)(local\.json|local\.machine\.json|\.env[^/]*|appsettings\.(?!example)[^/]*json)$|\.(pfx|p12|pem|key|bak|dll|exe|pdb|zip|log)$'
$secret='-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[0-9A-Z]{16}|(?i);\s*(?:Password|Pwd)\s*=\s*(?!YOUR_PASSWORD|<|\{)[^;\s"<>]{3,}'
$manifest=@();$blocked=@()
$trees=@(git -C $root worktree list --porcelain | Where-Object {$_ -like 'worktree *'} | ForEach-Object {$_.Substring(9)})
$trees+=@('C:/Work/laoo_visitor','C:/Work/Laoo/รวมprojectต้นแบบ/laoo_meeting')
foreach($p in $trees){
 if($p.Replace('\','/') -eq $Destination.Replace('\','/')){continue}
 if(-not(Test-Path -LiteralPath "$p/.git")){$manifest+=@{path=$p;status='missing'};continue}
 $label=(Split-Path $p -Leaf) -replace '[^a-zA-Z0-9_-]','_'
 if($p -like 'C:/Work/*'){$label='legacy-'+$label}
 $base=(git -C $p rev-parse HEAD).Trim();$branch=git -C $p branch --show-current
 $paths=@(git -C $p -c core.quotepath=false diff HEAD --name-only --no-renames)
 $paths+=@(git -C $p -c core.quotepath=false ls-files --others --exclude-standard)
 $rows=@()
 foreach($f in ($paths | Sort-Object -Unique)){
  if(-not $f){continue}
  $source=Join-Path $p $f;$state='saved';$hash=$null
  if($f -match $excluded){$state='excluded'}
  elseif(-not(Test-Path -LiteralPath $source -PathType Leaf)){$state='deleted'}
  elseif([IO.File]::ReadAllText($source) -match $secret){$state='withheld';$blocked+=@{worktree=$label;path=$f}}
  if($state -eq 'saved'){
   $target=Join-Path $out "$label/files/$f.snapshot"
   [void](New-Item -ItemType Directory -Force -Path (Split-Path $target))
   Copy-Item -LiteralPath $source -Destination $target
   $hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
  }
  $rows+=@{path=$f;status=$state;sha256=$hash}
 }
 $indexRows=@()
 foreach($f in @(git -C $p -c core.quotepath=false diff --cached --name-only --no-renames)){
  if(-not $f -or $f -match $excluded){continue}
  foreach($entry in @(git -C $p -c core.quotepath=false ls-files --stage -- $f)){
   if($entry -notmatch '^\d+ ([0-9a-f]+) ([0-3])\t'){continue}
   $oid=$Matches[1];$stage=$Matches[2];$target=Join-Path $out "$label/index-stage-$stage/$f.snapshot"
   $psi=New-Object Diagnostics.ProcessStartInfo
   $psi.FileName='git';$psi.Arguments="-C `"$p`" cat-file blob $oid";$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.CreateNoWindow=$true
   $proc=[Diagnostics.Process]::Start($psi);$ms=New-Object IO.MemoryStream
   $proc.StandardOutput.BaseStream.CopyTo($ms);$proc.WaitForExit();$bytes=$ms.ToArray()
   if([Text.Encoding]::UTF8.GetString($bytes) -match $secret){$blocked+=@{worktree=$label;path=$f;stage=$stage};continue}
   [void](New-Item -ItemType Directory -Force -Path (Split-Path $target));[IO.File]::WriteAllBytes($target,$bytes)
   $indexRows+=@{path=$f;stage=$stage;blob=$oid}
  }
 }
 $merge=git -C $p rev-parse -q --verify MERGE_HEAD 2>$null
 $manifest+=@{path=$p;label=$label;baseCommit=$base;branch=$branch;mergeHead=$merge;files=$rows;index=$indexRows}
 Write-Output "$label : $(@($rows|Where-Object {$_.status -eq 'saved'}).Count) saved, $($indexRows.Count) index versions"
}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $out 'worktrees.json') -Encoding UTF8
ConvertTo-Json -InputObject @($blocked) -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'withheld.json') -Encoding UTF8
git -C $root for-each-ref --format='%(refname) %(objectname)' refs/heads refs/remotes/origin | Set-Content -LiteralPath (Join-Path $out 'git-refs.txt') -Encoding UTF8
Write-Output "WITHHELD=$($blocked.Count)"
