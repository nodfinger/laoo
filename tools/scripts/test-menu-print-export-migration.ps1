$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand()
    $q.Transaction = $tx
    $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111120000_LAOO_menu_print_export_flags.sql'))
    [void]$q.ExecuteNonQuery()
    [void]$q.ExecuteNonQuery()
    $q.CommandText = @'
IF (SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.TDADMainMenu') AND name IN (N'AllowPrint',N'AllowExport') AND system_type_id=104 AND is_nullable=0)<>2 THROW 51001, 'Flags missing or invalid', 1;
IF (SELECT COUNT(*) FROM sys.default_constraints D JOIN sys.columns C ON C.default_object_id=D.object_id WHERE C.object_id=OBJECT_ID(N'dbo.TDADMainMenu') AND C.name IN(N'AllowPrint',N'AllowExport'))<>2 THROW 51002, 'Flag defaults missing', 1;
'@
    [void]$q.ExecuteNonQuery()
    Write-Output 'Print/export flags, defaults and repeat migration passed (rolled back).'
} finally {
    $tx.Rollback()
    $db.Close()
}
