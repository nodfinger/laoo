/* Configure the default stock receipt price mode at company and item level. */
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'ReceiveStockPriceModeCode') IS NULL
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp ADD ReceiveStockPriceModeCode nvarchar(20) NOT NULL
        CONSTRAINT DF_TDSTCompanySetUp_ReceiveStockPriceModeCode DEFAULT(N'CUSTOM');
END;

IF COL_LENGTH(N'dbo.TDIVItem', N'ReceiveStockPriceModeCode') IS NULL
BEGIN
    ALTER TABLE dbo.TDIVItem ADD ReceiveStockPriceModeCode nvarchar(20) NULL;
END;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_TDSTCompanySetUp_ReceiveStockPriceMode')
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp ADD CONSTRAINT CK_TDSTCompanySetUp_ReceiveStockPriceMode
        CHECK (ReceiveStockPriceModeCode IN (N'CUSTOM',N'LAST_RECEIPT',N'AVERAGE'));
END;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_TDIVItem_ReceiveStockPriceMode')
BEGIN
    ALTER TABLE dbo.TDIVItem ADD CONSTRAINT CK_TDIVItem_ReceiveStockPriceMode
        CHECK (ReceiveStockPriceModeCode IS NULL OR ReceiveStockPriceModeCode IN (N'CUSTOM',N'LAST_RECEIPT',N'AVERAGE'));
END;
GO
