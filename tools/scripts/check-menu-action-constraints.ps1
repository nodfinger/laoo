$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg=Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db=New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
try {
 $cmd=$db.CreateCommand()
 $cmd.CommandText="SELECT name, definition FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADRoleGroupPermission')"
 $r=$cmd.ExecuteReader()
 while($r.Read()){ Write-Output ($r.GetString(0)+' '+$r.GetString(1)) }
 $r.Close()
} finally {$db.Close()}
