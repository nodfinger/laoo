$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand()
    $q.Transaction = $tx
    $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111016000_LAOO_approval_pattern_catalog.sql'))
    [void]$q.ExecuteNonQuery()
    $q.CommandText = @'
IF (SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode=N'10011') <> 1 THROW 51000, 'Incorrect screen type', 1;
INSERT dbo.TDSTApprovalPatternCatalog(CompanyID,PatternCode,PatternName,PatternType,LevelsUp,UpdateBy) VALUES(-987654,N'test',N'test','LEVEL',2,1),(-987653,N'test',N'test','MANUAL',NULL,1);
INSERT dbo.TDSTApprovalPatternCatalogStep(CompanyID,PatternCode,StepNo,ApprovalCondition) VALUES(-987654,N'test',1,'ANY');
INSERT dbo.TDSTApprovalPatternCatalogPosition(CompanyID,PatternCode,StepNo,PositionCode,UnitScope) VALUES(-987654,N'test',1,N'X','DEPARTMENT');
IF (SELECT COUNT(*) FROM dbo.TDSTApprovalPatternCatalog WHERE PatternCode=N'test' AND CompanyID IN(-987654,-987653))<>2 THROW 51001, 'Company separation failed', 1;
DELETE dbo.TDSTApprovalPatternCatalog WHERE CompanyID=-987654 AND PatternCode=N'test';
IF EXISTS (SELECT 1 FROM dbo.TDSTApprovalPatternCatalogPosition WHERE CompanyID=-987654) THROW 51002, 'Cascade failed', 1;
'@
    [void]$q.ExecuteNonQuery()
    Write-Output 'Approval catalog migration, company keys and cascade passed; rolled back.'
} finally {
    $tx.Rollback()
    $db.Close()
}
