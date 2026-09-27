SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
