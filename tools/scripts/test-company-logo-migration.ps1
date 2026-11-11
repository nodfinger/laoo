$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx = $db.BeginTransaction()
try {
  $q = $db.CreateCommand(); $q.Transaction = $tx
  $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111150000_LAOO_company_logo.sql'))
  [void]$q.ExecuteNonQuery(); [void]$q.ExecuteNonQuery()
  $q.CommandText = "IF OBJECT_ID(N'dbo.TDSTCompanyLogo',N'U') IS NULL THROW 51000, 'Logo table missing', 1;"
  [void]$q.ExecuteNonQuery()
  Write-Output 'Logo migration and repeated execution passed; transaction rolled back.'
} finally { $tx.Rollback(); $db.Close() }
