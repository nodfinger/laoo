-- Isolated quantity-tracked rental item for two DEMO branches.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@co AND Username=N'c111');
DECLARE @source bigint=(SELECT ItemID FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemCode=N'NZ001');
IF @co IS NULL OR @actor IS NULL OR @source IS NULL THROW 60610,N'Rental quantity fixture prerequisites are missing.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemCode=N'RN-DEMO-QTY')
 INSERT dbo.TDIVItem(CompanyID,ItemGroupCode,ItemTypeCode,ItemCode,ItemName,UnitPrice,UnitCode,
 CostPrice,StockBalance,MinStock,PurchaseQuantity,IsActive,ItemKindCode,StockTrackingCode)
 SELECT @co,ItemGroupCode,ItemTypeCode,N'RN-DEMO-QTY',
 N'อุปกรณ์เช่าตามจำนวน [RN_20261009_DEMO]',0,UnitCode,0,3,0,0,1,N'GOODS',N'QUANTITY'
 FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemID=@source;
DECLARE @item bigint=(SELECT ItemID FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemCode=N'RN-DEMO-QTY');
IF @item IS NULL THROW 60611,N'Rental quantity fixture item was not created.',1;
DECLARE @wh table(WarehouseID bigint,Quantity int);
INSERT @wh(WarehouseID,Quantity)
SELECT WarehouseID,CASE WHEN WarehouseCode=N'HO-A' THEN 1 ELSE 2 END
FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseCode IN(N'HO-A',N'W110-A') AND IsActive=1;
IF (SELECT COUNT(*) FROM @wh)<>2 THROW 60612,N'Rental quantity fixture warehouses are missing.',1;
INSERT dbo.TDIVStockBalance(CompanyID,WarehouseID,ItemID,Quantity)
SELECT @co,W.WarehouseID,@item,W.Quantity FROM @wh W
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDIVStockBalance B
 WHERE B.CompanyID=@co AND B.WarehouseID=W.WarehouseID AND B.ItemID=@item);
INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,
DocumentDetailID,MovementType,Quantity,Remark,CreatedBy)
SELECT @co,W.WarehouseID,@item,N'RENTAL_TEST',W.WarehouseID,W.WarehouseID,N'RECEIPT',W.Quantity,
N'RN_20261009_DEMO',@actor
FROM @wh W WHERE NOT EXISTS(SELECT 1 FROM dbo.TDIVStockMovement M
 WHERE M.CompanyID=@co AND M.WarehouseID=W.WarehouseID AND M.ItemID=@item
 AND M.DocumentType=N'RENTAL_TEST' AND M.Remark=N'RN_20261009_DEMO');
