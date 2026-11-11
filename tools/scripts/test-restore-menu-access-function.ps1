$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg=Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db=New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx=$db.BeginTransaction()
try {
 $q=$db.CreateCommand(); $q.Transaction=$tx
 $q.CommandText=[IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111140000_LAOO_restore_menu_access_function.sql'))
 [void]$q.ExecuteNonQuery()
 $q.CommandText="DECLARE @user bigint,@company bigint; SELECT TOP 1 @user=UserID,@company=CompanyID FROM dbo.TDADUser WHERE NormalizedUsername=N'P' AND IsActive=1; IF @user IS NULL THROW 51000,'Test user unavailable',1; IF dbo.LaooMenuDataAccessAllowed(@company,@user,@user,N'66001','VIEW')<>1 THROW 51001,'Self access failed',1;"
 [void]$q.ExecuteNonQuery()
 Write-Output 'Restored function and self access verified in rollback transaction.'
} finally { $tx.Rollback(); $db.Close() }
