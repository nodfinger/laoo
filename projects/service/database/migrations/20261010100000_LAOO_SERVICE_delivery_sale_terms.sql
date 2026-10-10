SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.TDARDeliveryNote', N'U') IS NULL
    THROW 51000, N'TDARDeliveryNote is missing', 1;
IF COL_LENGTH(N'dbo.TDARDeliveryNote', N'SaleTypeCode') IS NULL
    ALTER TABLE dbo.TDARDeliveryNote ADD SaleTypeCode nvarchar(10) NULL;
IF COL_LENGTH(N'dbo.TDARDeliveryNote', N'CreditDays') IS NULL
    ALTER TABLE dbo.TDARDeliveryNote ADD CreditDays int NULL;
IF COL_LENGTH(N'dbo.TDARDeliveryNote', N'DueDate') IS NULL
    ALTER TABLE dbo.TDARDeliveryNote ADD DueDate date NULL;
COMMIT TRANSACTION;
