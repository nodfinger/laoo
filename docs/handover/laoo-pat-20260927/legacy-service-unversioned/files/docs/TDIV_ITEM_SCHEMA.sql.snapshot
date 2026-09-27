/* Product master schema for MenuCode 08001 (ScreenType 1 / CRUD)
   Run only after verifying the target database and existing dependencies. */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Replace the test-only legacy product table after checking dependencies. */
IF OBJECT_ID(N'dbo.TDIVItem', N'U') IS NOT NULL
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE referenced_object_id = OBJECT_ID(N'dbo.TDIVItem')
    )
    BEGIN
        THROW 51000, 'dbo.TDIVItem ยังมีตารางอื่นอ้างอิงอยู่ ต้องจัดการ Foreign Key ก่อน', 1;
    END;

    DROP TABLE dbo.TDIVItem;
END;
GO

IF OBJECT_ID(N'dbo.TDIVItem', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItem
    (
        ItemID BIGINT IDENTITY(1,1) NOT NULL,
        CompanyID BIGINT NOT NULL,
        ItemGroupCode NVARCHAR(50) NOT NULL,
        ItemTypeCode NVARCHAR(50) NOT NULL,
        ItemCode NVARCHAR(50) NOT NULL,
        ItemName NVARCHAR(200) NOT NULL,
        UnitPrice DECIMAL(18,4) NOT NULL CONSTRAINT DF_TDIVItem_UnitPrice DEFAULT (0),
        UnitCode NVARCHAR(50) NOT NULL,
        CostPrice DECIMAL(18,4) NOT NULL CONSTRAINT DF_TDIVItem_CostPrice DEFAULT (0),
        StockBalance DECIMAL(18,4) NOT NULL CONSTRAINT DF_TDIVItem_StockBalance DEFAULT (0),
        MinStock DECIMAL(18,4) NOT NULL CONSTRAINT DF_TDIVItem_MinStock DEFAULT (0),
        PurchaseQuantity DECIMAL(18,4) NOT NULL CONSTRAINT DF_TDIVItem_PurchaseQuantity DEFAULT (0),
        RemarkItem1 NVARCHAR(2000) NULL,
        Note1 NVARCHAR(1000) NULL,
        Note2 NVARCHAR(1000) NULL,
        Note3 NVARCHAR(1000) NULL,
        Note4 NVARCHAR(1000) NULL,
        Note5 NVARCHAR(1000) NULL,
        OrderCode NVARCHAR(400) NULL,
        OrderLink1 NVARCHAR(2000) NULL,
        OrderLink2 NVARCHAR(2000) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDIVItem_IsActive DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL CONSTRAINT DF_TDIVItem_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2(3) NULL,
        CONSTRAINT PK_TDIVItem PRIMARY KEY (ItemID),
        CONSTRAINT UQ_TDIVItem_Company_ItemCode UNIQUE (CompanyID, ItemCode),
        CONSTRAINT CK_TDIVItem_Prices CHECK (UnitPrice >= 0 AND CostPrice >= 0),
        CONSTRAINT CK_TDIVItem_Stocks CHECK (StockBalance >= 0 AND MinStock >= 0 AND PurchaseQuantity >= 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.TDIVItemImage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemImage
    (
        ItemImageID BIGINT IDENTITY(1,1) NOT NULL,
        ItemID BIGINT NOT NULL,
        ImageData VARBINARY(MAX) NULL,
        FilePath NVARCHAR(500) NULL,
        ContentType NVARCHAR(100) NOT NULL,
        FileName NVARCHAR(250) NULL,
        IsCover BIT NOT NULL CONSTRAINT DF_TDIVItemImage_IsCover DEFAULT (0),
        SortOrder INT NOT NULL CONSTRAINT DF_TDIVItemImage_SortOrder DEFAULT (1),
        IsActive BIT NOT NULL CONSTRAINT DF_TDIVItemImage_IsActive DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL CONSTRAINT DF_TDIVItemImage_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2(3) NULL,
        CONSTRAINT PK_TDIVItemImage PRIMARY KEY (ItemImageID),
        CONSTRAINT FK_TDIVItemImage_Item FOREIGN KEY (ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT CK_TDIVItemImage_SortOrder CHECK (SortOrder BETWEEN 1 AND 5)
    );
    CREATE UNIQUE INDEX UX_TDIVItemImage_Cover ON dbo.TDIVItemImage(ItemID) WHERE IsCover = 1 AND IsActive = 1;
    CREATE UNIQUE INDEX UX_TDIVItemImage_Order ON dbo.TDIVItemImage(ItemID, SortOrder) WHERE IsActive = 1;
END;
GO

IF OBJECT_ID(N'dbo.TDIVItemPackUnit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemPackUnit
    (
        ItemPackUnitID BIGINT IDENTITY(1,1) NOT NULL,
        ItemID BIGINT NOT NULL,
        UnitCode NVARCHAR(50) NOT NULL,
        ParentUnitCode NVARCHAR(50) NULL,
        ConversionQuantity DECIMAL(18,6) NOT NULL,
        BaseQuantity DECIMAL(18,6) NOT NULL,
        IsDefault BIT NOT NULL CONSTRAINT DF_TDIVItemPackUnit_IsDefault DEFAULT (0),
        SortOrder INT NOT NULL CONSTRAINT DF_TDIVItemPackUnit_SortOrder DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL CONSTRAINT DF_TDIVItemPackUnit_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2(3) NULL,
        CONSTRAINT PK_TDIVItemPackUnit PRIMARY KEY (ItemPackUnitID),
        CONSTRAINT FK_TDIVItemPackUnit_Item FOREIGN KEY (ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT UQ_TDIVItemPackUnit_Item_Unit UNIQUE (ItemID, UnitCode),
        CONSTRAINT CK_TDIVItemPackUnit_Quantity CHECK (ConversionQuantity > 0 AND BaseQuantity > 0)
    );
    CREATE UNIQUE INDEX UX_TDIVItemPackUnit_Default ON dbo.TDIVItemPackUnit(ItemID) WHERE IsDefault = 1;
END;
GO
