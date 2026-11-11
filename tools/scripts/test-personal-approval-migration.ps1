$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open(); $tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand(); $q.Transaction = $tx
    $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111210000_LAOO_personal_approval.sql'))
    [void]$q.ExecuteNonQuery(); [void]$q.ExecuteNonQuery()
    $q.CommandText = @'
SET XACT_ABORT OFF;
DECLARE @company bigint=(SELECT TOP(1) CompanyID FROM dbo.TDADEmployee WHERE IsActive=1 AND CompanyID IS NOT NULL GROUP BY CompanyID HAVING COUNT(*)>=2 ORDER BY CompanyID);
DECLARE @requester bigint=(SELECT MIN(EmployeeID) FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1);
DECLARE @approver bigint=(SELECT MAX(EmployeeID) FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1);
IF @company IS NULL THROW 54250,'Not enough employees for rollback test',1;
INSERT dbo.TDSTPersonalApprovalStep(CompanyID,MenuCode,RequesterEmployeeID,StepNo,ApproverEmployeeID,UpdateBy) VALUES(@company,'66001',@requester,1,@approver,1);
BEGIN TRY
 INSERT dbo.TDSTPersonalApprovalStep(CompanyID,MenuCode,RequesterEmployeeID,StepNo,ApproverEmployeeID,UpdateBy) VALUES(@company,'66001',@requester,2,@approver,1);
 THROW 54251,'Duplicate approver accepted',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER() NOT IN (2601,2627) THROW;
END CATCH;
BEGIN TRY
 INSERT dbo.TDSTPersonalApprovalStep(CompanyID,MenuCode,RequesterEmployeeID,StepNo,ApproverEmployeeID,UpdateBy) VALUES(@company,'66001',@requester,2,@requester,1);
 THROW 54252,'Self approval accepted',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>547 THROW;
END CATCH;
'@
    [void]$q.ExecuteNonQuery()
    Write-Output 'Personal approval migration and constraints passed; rolled back.'
} finally { $tx.Rollback(); $db.Close() }
