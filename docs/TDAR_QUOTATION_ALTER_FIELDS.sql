SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDARQuotation', N'U') IS NULL
    THROW 50001, 'ไม่พบตาราง dbo.TDARQuotation', 1;

IF COL_LENGTH(N'dbo.TDARQuotation', N'ContactName') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD ContactName nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'ValidDays') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD ValidDays int NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'SalesType') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD SalesType nvarchar(100) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'PaymentType') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD PaymentType nvarchar(50) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'CreditDays') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD CreditDays int NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'TotalAmount') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD TotalAmount decimal(18,2) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'DiscountPercent') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD DiscountPercent decimal(9,2) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'DiscountAmount') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD DiscountAmount decimal(18,2) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'AmountAfterDiscount') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD AmountAfterDiscount decimal(18,2) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'TaxPercent') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD TaxPercent decimal(9,2) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'TaxAmount') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD TaxAmount decimal(18,2) NULL;
IF COL_LENGTH(N'dbo.TDARQuotation', N'NetAmount') IS NULL
    ALTER TABLE dbo.TDARQuotation ADD NetAmount decimal(18,2) NULL;

COMMIT TRANSACTION;
