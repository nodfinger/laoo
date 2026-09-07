SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTSchemaMigration',N'U') IS NULL
    THROW 52306,N'Run migration 20260907090000 before inventory menu migration',1;

DECLARE @Menus table
(
    MenuCode nvarchar(20),MenuName nvarchar(200),ScreenType int,
    RouteName nvarchar(100),RoutePath nvarchar(300),IconName nvarchar(100),SortOrder int
);
INSERT @Menus VALUES
(N'08004',N'คลังสินค้า',1,N'warehouses',N'/inventory/warehouses',N'warehouse_outlined',4),
(N'08005',N'รับสินค้าเข้าคลังและยอดยกมา',4,N'stockReceipts',N'/inventory/stock-receipts',N'inventory_outlined',5),
(N'08006',N'ทะเบียน Serial/อุปกรณ์',1,N'itemInstances',N'/inventory/item-instances',N'qr_code_2_outlined',6);

UPDATE T SET T.MenuGroupCode=N'08',T.MenuName=S.MenuName,T.ScreenType=S.ScreenType,
    T.RouteName=S.RouteName,T.RoutePath=S.RoutePath,T.IconName=S.IconName,T.SortOrder=S.SortOrder,
    T.IsVisible=1,T.IsFavoriteAllowed=1,T.IsActive=1,T.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADMainMenu T JOIN @Menus S ON S.MenuCode=T.MenuCode;

INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
SELECT S.MenuCode,N'08',S.MenuName,S.ScreenType,S.RouteName,S.RoutePath,NULL,S.IconName,S.SortOrder,1,1,1
FROM @Menus S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu T WHERE T.MenuCode=S.MenuCode);

