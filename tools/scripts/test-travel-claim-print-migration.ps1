$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg=Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db=New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx=$db.BeginTransaction()
try {
  $q=$db.CreateCommand(); $q.Transaction=$tx
  $q.CommandText=[IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111130000_LAOO_travel_claim_print.sql'))
  [void]$q.ExecuteNonQuery(); [void]$q.ExecuteNonQuery()
  $q.CommandText="IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'66001' AND AllowPrint=1) THROW 51000, 'Print flag failed',1;"
  [void]$q.ExecuteNonQuery()
  Write-Output 'Travel claim print flag and repeat migration passed (rolled back).'
} finally { $tx.Rollback(); $db.Close() }
