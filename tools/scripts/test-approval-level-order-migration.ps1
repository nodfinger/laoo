$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx = $db.BeginTransaction()
try {
  $q = $db.CreateCommand(); $q.Transaction = $tx
  $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111180000_LAOO_approval_level_order.sql'))
  [void]$q.ExecuteNonQuery(); [void]$q.ExecuteNonQuery()
  $q.CommandText = "INSERT dbo.TDSTCompanyApprovalLevelOrder(CompanyID,OrderMethod,UpdateBy) VALUES (-987654,'NAME',1),(-987653,'SEQUENCE',1); IF (SELECT COUNT(*) FROM dbo.TDSTCompanyApprovalLevelOrder WHERE CompanyID IN (-987654,-987653))<>2 THROW 51001, 'Company separation failed', 1;"
  [void]$q.ExecuteNonQuery()
  Write-Output 'Migration and company isolation passed; rolled back.'
} finally { $tx.Rollback(); $db.Close() }
