$ErrorActionPreference='Stop'
$out=Join-Path (Get-Location) 'docs/handover/laoo-pat-20260927'
$exclude='(^|/)(\.git|\.dart_tool|build|bin|obj|node_modules|uploads|tmp|output|backups|ephemeral|\.gradle|\.artifacts|\.tmp[^/]*)(/|$)|generated_plugin|GeneratedPlugin|(^|/)(local[^/]*\.json|appsettings[^/]*\.json|\.env[^/]*|\.flutter-plugins-dependencies|local\.properties|Generated\.xcconfig|flutter_export_environment\.sh)$|\.(pfx|p12|pem|key|bak|dll|exe|pdb|zip|log)$'
$secret='-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[0-9A-Z]{16}|(?i);\s*(?:Password|Pwd)\s*=\s*(?!YOUR_PASSWORD|<|\{)[^;\s"<>]{3,}'
$manifest=@()
foreach($repo in @('C:/laooplatform/laoo','C:/Work/laoo_visitor','C:/Work/Laoo/รวมprojectต้นแบบ/laoo_meeting')){
 foreach($oid in @(git -C $repo stash list --format='%H')){
  $parents=(git -C $repo rev-list --parents -n 1 $oid).Split(' ')
  $base=$parents[1];$index=$parents[2];$files=@()
  $versions=@(@{role='working';commit=$oid},@{role='index';commit=$index})
  if($parents.Length -gt 3){$versions+=@{role='untracked';commit=$parents[3]}}
  foreach($v in $versions){
   $paths=if($v.role -eq 'untracked'){@(git -C $repo -c core.quotepath=false ls-tree -r --name-only $v.commit)}else{@(git -C $repo -c core.quotepath=false diff --name-only --no-renames $base $v.commit)}
   foreach($f in $paths){
    $state='saved';$blob=$null
    if($f -match $exclude){$state='excluded'}
    else{
     $blob=git -C $repo rev-parse -q --verify "$($v.commit):$f" 2>$null
     if(-not $blob){$state='deleted'}
     else{
      $psi=New-Object Diagnostics.ProcessStartInfo
      $psi.FileName='git';$psi.Arguments='-C "'+$repo+'" cat-file blob '+$blob;$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.CreateNoWindow=$true
      $proc=[Diagnostics.Process]::Start($psi);$ms=New-Object IO.MemoryStream;$proc.StandardOutput.BaseStream.CopyTo($ms);$proc.WaitForExit();$bytes=$ms.ToArray()
      if([Text.Encoding]::UTF8.GetString($bytes) -match $secret){$state='withheld-credential-review'}
      else{
       $target=Join-Path $out "stashes/$oid/$($v.role)/$f.snapshot"
       [void](New-Item -ItemType Directory -Force -Path (Split-Path $target))
       [IO.File]::WriteAllBytes($target,$bytes)
      }
     }
    }
    $files+=@{path=$f;role=$v.role;status=$state;blob=$blob}
   }
  }
  $manifest+=@{repository=$repo;stash=$oid;baseCommit=$base;message=(git -C $repo show -s --format='%s' $oid);files=$files}
  Write-Output "$oid : $(@($files|Where-Object status -eq saved).Count) source versions"
 }
}
ConvertTo-Json -InputObject @($manifest) -Depth 10|Set-Content (Join-Path $out 'stashes.json') -Encoding UTF8
