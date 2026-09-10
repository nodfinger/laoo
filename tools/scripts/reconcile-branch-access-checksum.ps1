param([string]$Root = (Resolve-Path "$PSScriptRoot/../..").Path)
$ErrorActionPreference = 'Stop'
$migration = '20260909100000_LAOO_branch_warehouse_user_access'
$legacy = '009346B04678B7ABFF0D71591DB272EC19061640E447CC6CC2EE40F2FDBA0B8D'
$sqlFile = [IO.File]::ReadAllText((Join-Path $Root "database/migrations/$migration.sql")).Replace([string][char]13+[char]10,[string][char]10).Replace([char]13,[char]10)
$sha = [Security.Cryptography.SHA256]::Create()
$checksum = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($sqlFile))).Replace('-','')
$sha.Dispose()
$cfg = Get-Content (Join-Path $Root 'laoo_api/local.json') -Raw | ConvertFrom-Json
$connection = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$connection.Open()
$tx = $connection.BeginTransaction()
try {
    $cmd = $connection.CreateCommand()
    $cmd.Transaction = $tx
    $cmd.CommandText = @'
DECLARE @lock int;
EXEC @lock=sys.sp_getapplock @Resource=N'LAOO_SCHEMA_MIGRATION',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=60000;
IF @lock<0 THROW 52710,'Cannot acquire migration lock.',1;
DECLARE @actual varchar(64)=(SELECT Checksum FROM dbo.TDSTSchemaMigration WITH(UPDLOCK,HOLDLOCK) WHERE MigrationID=@id);
IF @actual=@checksum BEGIN SELECT 'Already reconciled'; RETURN; END;
IF @actual IS NULL OR @actual<>@legacy THROW 52711,'Unknown checksum: manual review required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TDADBranch') AND name='AccessModeCode' AND TYPE_NAME(user_type_id)='nvarchar' AND max_length=40 AND is_nullable=0)
 OR NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TDIVWarehouse') AND name='AccessModeCode' AND TYPE_NAME(user_type_id)='nvarchar' AND max_length=40 AND is_nullable=0)
 THROW 52712,'Branch or warehouse access column mismatch.',1;
IF NOT EXISTS(SELECT 1 FROM sys.default_constraints WHERE name='DF_TDADBranch_AccessModeCode' AND parent_object_id=OBJECT_ID('dbo.TDADBranch') AND definition LIKE '%ALL%')
 OR NOT EXISTS(SELECT 1 FROM sys.default_constraints WHERE name='DF_TDIVWarehouse_AccessModeCode' AND parent_object_id=OBJECT_ID('dbo.TDIVWarehouse') AND definition LIKE '%INHERIT%')
 THROW 52713,'Access default mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE name IN('CK_TDADBranch_AccessModeCode','CK_TDIVWarehouse_AccessModeCode') AND is_disabled=0 AND is_not_trusted=0)<>2
 THROW 52714,'Access constraints missing or untrusted.',1;
DECLARE @expected TABLE(Name sysname,Type sysname,Nullable bit);
INSERT @expected VALUES('UserWarehouseID','bigint',0),('CompanyID','bigint',0),('WarehouseID','bigint',0),('UserID','bigint',0),('IsActive','bit',0),('CreateDate','datetime2',0),('CreatedBy','bigint',1),('UpdateDate','datetime2',1),('UpdatedBy','bigint',1);
IF OBJECT_ID('dbo.TDIVUserWarehouse','U') IS NULL OR EXISTS(
 SELECT Name,Type,Nullable FROM @expected EXCEPT
 SELECT name,TYPE_NAME(user_type_id),is_nullable FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TDIVUserWarehouse'))
 THROW 52715,'User warehouse schema mismatch.',1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID('dbo.TDIVUserWarehouse') AND name IN('FK_TDIVUserWarehouse_Warehouse','FK_TDIVUserWarehouse_User') AND is_disabled=0 AND is_not_trusted=0)<>2
 OR NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TDIVUserWarehouse') AND name='UQ_TDIVUserWarehouse_Company_Warehouse_User' AND is_unique=1 AND is_disabled=0)
 OR NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TDIVUserWarehouse') AND name='IX_TDIVUserWarehouse_User_Access' AND is_disabled=0)
 THROW 52716,'Warehouse relation constraints or indexes missing.',1;
IF EXISTS(SELECT 1 FROM dbo.TDSTSchemaMigration WHERE MigrationID=@audit)
 THROW 52717,'Audit record already exists with unreconciled source; review required.',1;
INSERT dbo.TDSTSchemaMigration(MigrationID,ProjectCode,Checksum,AppliedUtc,AppliedBy,SourceMachine)
SELECT @audit,ProjectCode,Checksum,AppliedUtc,AppliedBy,SourceMachine FROM dbo.TDSTSchemaMigration WHERE MigrationID=@id;
UPDATE dbo.TDSTSchemaMigration SET Checksum=@checksum WHERE MigrationID=@id AND Checksum=@legacy;
IF @@ROWCOUNT<>1 THROW 52718,'Ledger changed concurrently.',1;
SELECT 'Reconciled legacy v1 checksum; original evidence preserved; no business rows changed';
'@
    [void]$cmd.Parameters.AddWithValue('@id',$migration)
    [void]$cmd.Parameters.AddWithValue('@audit',($migration + '_legacy_v1_checksum'))
    [void]$cmd.Parameters.AddWithValue('@legacy',$legacy)
    [void]$cmd.Parameters.AddWithValue('@checksum',$checksum)
    Write-Output $cmd.ExecuteScalar()
    $tx.Commit()
} catch {
    $tx.Rollback()
    throw
} finally {
    $tx.Dispose()
    $connection.Dispose()
}
