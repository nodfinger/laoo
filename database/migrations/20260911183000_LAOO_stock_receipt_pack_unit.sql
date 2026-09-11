SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDIVStockReceiptDetail', N'ReceiptUnitCode') IS NULL
    ALTER TABLE dbo.TDIVStockReceiptDetail ADD ReceiptUnitCode nvarchar(50) NULL;

IF COL_LENGTH(N'dbo.TDIVStockReceiptDetail', N'ReceiptQuantity') IS NULL
    ALTER TABLE dbo.TDIVStockReceiptDetail ADD ReceiptQuantity decimal(18,4) NULL;

IF COL_LENGTH(N'dbo.TDIVStockReceiptDetail', N'BaseUnitCode') IS NULL
    ALTER TABLE dbo.TDIVStockReceiptDetail ADD BaseUnitCode nvarchar(50) NULL;

IF COL_LENGTH(N'dbo.TDIVStockReceiptDetail', N'UnitConversionFactor') IS NULL
    ALTER TABLE dbo.TDIVStockReceiptDetail ADD UnitConversionFactor decimal(18,6) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE name=N'CK_TDIVStockReceiptDetail_UnitSnapshot'
)
    EXEC sys.sp_executesql N'
        ALTER TABLE dbo.TDIVStockReceiptDetail WITH CHECK
        ADD CONSTRAINT CK_TDIVStockReceiptDetail_UnitSnapshot CHECK
        (
            (ReceiptUnitCode IS NULL AND ReceiptQuantity IS NULL AND BaseUnitCode IS NULL AND UnitConversionFactor IS NULL)
            OR
            (ReceiptUnitCode IS NOT NULL AND ReceiptQuantity>0 AND BaseUnitCode IS NOT NULL AND UnitConversionFactor>0)
        );';
