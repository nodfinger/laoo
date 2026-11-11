$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand()
    $q.Transaction = $tx
    $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111110000_LAOO_employee_signature.sql'))
    [void]$q.ExecuteNonQuery()
    [void]$q.ExecuteNonQuery()
    $q.CommandText = @'
IF (SELECT COUNT(*) FROM dbo.TDADUserPermissionPointName WHERE MenuCode=N'10001' AND PermissionPointCode=N'MANAGE_EMPLOYEE_SIGNATURE')<>1 THROW 51001, 'Permission registration failed', 1;
INSERT dbo.TDADEmployeeSignature(EmployeeID,CompanyID,ImageData,ContentType,FileName,UpdatedBy) VALUES(-987654,-987653,0x89504E470D0A1A0A,N'image/png',N'test.png',-1);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADEmployeeSignature WHERE EmployeeID=-987654 AND CompanyID=-987653) THROW 51002, 'Signature storage failed', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADEmployeeSignature WHERE EmployeeID=-987654 AND CompanyID=-987652) THROW 51003, 'Company isolation failed', 1;
'@
    [void]$q.ExecuteNonQuery()
    Write-Output 'Signature migration, idempotence and company isolation passed (rolled back).'
} finally {
    $tx.Rollback()
    $db.Close()
}
