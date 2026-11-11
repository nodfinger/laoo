$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open(); $tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand(); $q.Transaction = $tx
    $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111200000_LAOO_approval_assignment.sql'))
    [void]$q.ExecuteNonQuery(); [void]$q.ExecuteNonQuery()
    $q.CommandText = "IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode='68002' AND ScreenType=3 AND AllowPrint=0 AND AllowExport=0 AND AllowListDisplaySettings=0) THROW 54230, 'Invalid menu configuration',1;"
    [void]$q.ExecuteNonQuery()
    $q.CommandText = @'
SET XACT_ABORT OFF;
INSERT dbo.TDSTApprovalPatternCatalog(CompanyID,PatternCode,PatternName,PatternType,LevelsUp,UpdateBy)
VALUES(-987654,N'test',N'test','MANUAL',NULL,1),(-987653,N'test',N'test','MANUAL',NULL,1);
INSERT dbo.TDSTMenuApprovalAssignment(CompanyID,MenuCode,PatternCode,UpdateBy)
VALUES(-987654,'66001',N'test',1),(-987653,'66001',N'test',1);
IF (SELECT COUNT(*) FROM dbo.TDSTMenuApprovalAssignment WHERE CompanyID IN(-987654,-987653) AND MenuCode='66001')<>2 THROW 54233,'Company isolation failed',1;
BEGIN TRY
 INSERT dbo.TDSTMenuApprovalAssignment(CompanyID,MenuCode,PatternCode,UpdateBy) VALUES(-987652,'66001',N'test',1);
 THROW 54234,'Cross-company pattern accepted',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>547 THROW;
END CATCH;
'@
    [void]$q.ExecuteNonQuery()
    Write-Output 'Approval assignment migration verified; rolled back.'
} finally { $tx.Rollback(); $db.Close() }
