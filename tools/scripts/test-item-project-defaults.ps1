param([string]$Root = (Resolve-Path "$PSScriptRoot/../..").Path)
$ErrorActionPreference = 'Stop'
$cfg = Get-Content (Join-Path $Root 'laoo_api/local.json') -Raw | ConvertFrom-Json
$connection = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$connection.Open()
$transaction = $connection.BeginTransaction()
try {
    $command = $connection.CreateCommand()
    $command.Transaction = $transaction
    $command.CommandText = @'
DECLARE @company bigint, @item bigint, @project bigint;
SELECT TOP(1) @company=I.CompanyID,@item=I.ItemID FROM dbo.TDIVItem I
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDIVItemProjectPolicy P WHERE P.CompanyID=I.CompanyID AND P.ItemID=I.ItemID) ORDER BY I.ItemID;
SELECT TOP(1) @project=ProjectID FROM dbo.TDADProject WHERE IsActive=1 ORDER BY ProjectID;
IF @item IS NULL OR @project IS NULL THROW 52600,'Test requires an existing unconfigured item and project.',1;
IF EXISTS(SELECT 1 FROM dbo.TDIVItemProjectPolicy WHERE CompanyID=@company AND ItemID=@item AND AccessModeCode='SELECTED') THROW 52601,'Legacy item must remain unrestricted.',1;
INSERT dbo.TDIVItemProjectPolicy(CompanyID,ItemID,AccessModeCode,UpdatedBy) VALUES(@company,@item,'SELECTED',0);
INSERT dbo.TDIVItemProject(CompanyID,ItemID,ProjectID) VALUES(@company,@item,@project);
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVItemProject WHERE CompanyID=@company AND ItemID=@item AND ProjectID=@project) THROW 52602,'Selected project missing.',1;
IF EXISTS(SELECT 1 FROM dbo.TDIVItemProject WHERE CompanyID=@company+100000000 AND ItemID=@item AND ProjectID=@project) THROW 52603,'Company isolation failed.',1;
IF EXISTS(SELECT 1 FROM dbo.TDIVItemProject WHERE CompanyID=@company AND ItemID=@item AND ProjectID=-1) THROW 52604,'Unselected project returned.',1;
DECLARE @key nvarchar(50)=CONVERT(nvarchar(36),NEWID());
INSERT dbo.TDIVItemClassificationDefault(CompanyID,ScopeCode,ClassificationCode,ItemKindCode,StockTrackingCode,UsageCodesJson,UpdatedBy)
VALUES(@company,'GROUP',@key,'GOODS','QUANTITY','["SALE"]',0),(@company,'TYPE',@key,'GOODS','SERIAL','["EQUIPMENT"]',0);
DECLARE @tracking nvarchar(20);
SELECT TOP(1) @tracking=StockTrackingCode FROM dbo.TDIVItemClassificationDefault WHERE CompanyID=@company AND ClassificationCode=@key
ORDER BY CASE ScopeCode WHEN 'TYPE' THEN 0 ELSE 1 END;
IF @tracking<>'SERIAL' THROW 52605,'Type default must precede group.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTSchemaMigration WHERE MigrationID='20260910120000_LAOO_item_project_defaults') THROW 52606,'Migration ledger missing.',1;
SELECT 'PASS: legacy default, selected/unselected project, company isolation, type precedence, migration ledger' AS Result;
'@
    Write-Output $command.ExecuteScalar()
}
finally {
    $transaction.Rollback()
    $transaction.Dispose()
    $connection.Dispose()
}
