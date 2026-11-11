$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand(); $q.Transaction = $tx
    $sql = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111191000_LAOO_approval_system_name.sql'))
    $expected = [regex]::Match($sql, "ProjectNameTH=N'([^']+)'").Groups[1].Value
    $q.CommandText = $sql
    [void]$q.ExecuteNonQuery(); [void]$q.ExecuteNonQuery()
    $q.CommandText = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_APPROVAL' AND ProjectNameTH=@expected) AND EXISTS(SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'APPROVAL_SYSTEM' AND FeatureName=@expected) THEN 1 ELSE 0 END"
    [void]$q.Parameters.AddWithValue('@expected', $expected)
    if ([int]$q.ExecuteScalar() -ne 1) { throw 'Approval system name verification failed.' }
    Write-Output 'Approval system rename verified and rolled back.'
} finally { $tx.Rollback(); $db.Close() }
