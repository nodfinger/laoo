SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @LockResult int;
EXEC @LockResult=sys.sp_getapplock @Resource=N'LAOO_SCHEMA_MIGRATION',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=60000;
IF @LockResult<0 THROW 52303,N'Unable to acquire LAOO schema migration lock',1;
IF OBJECT_ID(N'dbo.TDSTSchemaMigration',N'U') IS NULL
    THROW 52304,N'Run migration 20260907090000 before opening stock migration',1;
IF EXISTS(SELECT 1 FROM dbo.TDSTSchemaMigration WHERE ProjectCode=N'LAOO_SERVICE' AND MigrationCode=N'20260907091000')
BEGIN
    COMMIT TRANSACTION;
    RETURN;
END;

IF EXISTS
(
    SELECT 1 FROM dbo.TDIVItem I
    WHERE I.StockBalance<>0
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.TDIVWarehouse W
          WHERE W.CompanyID=I.CompanyID AND W.IsDefault=1 AND W.IsActive=1
      )
)
    THROW 52301,N'Every company with legacy stock must have an active default warehouse',1;

INSERT dbo.TDIVStockBalance(CompanyID,WarehouseID,ItemID,Quantity)
SELECT I.CompanyID,W.WarehouseID,I.ItemID,I.StockBalance
FROM dbo.TDIVItem I
JOIN dbo.TDIVWarehouse W ON W.CompanyID=I.CompanyID AND W.IsDefault=1 AND W.IsActive=1
WHERE I.StockBalance<>0
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.TDIVStockMovement M
      WHERE M.CompanyID=I.CompanyID AND M.ItemID=I.ItemID
        AND M.MovementType=N'OPENING' AND M.DocumentType=N'ITEM_MIGRATION'
  )
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.TDIVStockBalance B
      WHERE B.CompanyID=I.CompanyID AND B.WarehouseID=W.WarehouseID AND B.ItemID=I.ItemID
  );

INSERT dbo.TDIVStockMovement
(
    CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,
    MovementType,Quantity,Remark
)
SELECT I.CompanyID,W.WarehouseID,I.ItemID,N'ITEM_MIGRATION',I.ItemID,I.ItemID,
       N'OPENING',I.StockBalance,N'Migrated from TDIVItem.StockBalance'
FROM dbo.TDIVItem I
JOIN dbo.TDIVWarehouse W ON W.CompanyID=I.CompanyID AND W.IsDefault=1 AND W.IsActive=1
WHERE I.StockBalance<>0
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.TDIVStockMovement M
      WHERE M.CompanyID=I.CompanyID AND M.ItemID=I.ItemID
        AND M.MovementType=N'OPENING' AND M.DocumentType=N'ITEM_MIGRATION'
  );

IF EXISTS
(
    SELECT I.CompanyID,I.ItemID
    FROM dbo.TDIVItem I
    LEFT JOIN dbo.TDIVStockBalance B ON B.CompanyID=I.CompanyID AND B.ItemID=I.ItemID
    GROUP BY I.CompanyID,I.ItemID,I.StockBalance
    HAVING I.StockBalance<>COALESCE(SUM(B.Quantity),0)
)
    THROW 52302,N'Warehouse totals do not match TDIVItem.StockBalance',1;

INSERT dbo.TDSTSchemaMigration(ProjectCode,MigrationCode,Checksum)
VALUES(N'LAOO_SERVICE',N'20260907091000',HASHBYTES('SHA2_256',N'opening-stock-v1'));

COMMIT TRANSACTION;
