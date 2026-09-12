/*
  Company-level inventory policy used by the Core company setup card.
  Inventory workflows may read this value; this migration does not change
  the existing receipt/stock transaction behavior.
*/
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'ReceiveStockImmediately') IS NULL
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp
        ADD ReceiveStockImmediately bit NOT NULL
            CONSTRAINT DF_TDSTCompanySetUp_ReceiveStockImmediately DEFAULT (1);
END;
GO
