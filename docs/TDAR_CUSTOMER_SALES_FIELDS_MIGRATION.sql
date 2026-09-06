/*
  Customer sales settings for dbo.TDARCustomer.
  SalesAreaCode is deliberately NOT included.
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDARCustomer', N'TaxID') IS NULL
  ALTER TABLE dbo.TDARCustomer ADD TaxID nvarchar(50) NULL;

IF COL_LENGTH(N'dbo.TDARCustomer', N'PaymentType') IS NULL
  ALTER TABLE dbo.TDARCustomer ADD PaymentType nvarchar(10) NULL;

IF COL_LENGTH(N'dbo.TDARCustomer', N'CreditDays') IS NULL
  ALTER TABLE dbo.TDARCustomer ADD CreditDays int NULL;

IF COL_LENGTH(N'dbo.TDARCustomer', N'CreditLimit') IS NULL
  ALTER TABLE dbo.TDARCustomer ADD CreditLimit decimal(18,4) NULL;

IF COL_LENGTH(N'dbo.TDARCustomer', N'SalespersonEmployeeID') IS NULL
  ALTER TABLE dbo.TDARCustomer ADD SalespersonEmployeeID bigint NULL;

IF COL_LENGTH(N'dbo.TDARCustomer', N'TaxType') IS NULL
  ALTER TABLE dbo.TDARCustomer ADD TaxType nvarchar(20) NULL;

COMMIT TRANSACTION;

SELECT
  COL_LENGTH(N'dbo.TDARCustomer', N'TaxID') AS TaxIDLength,
  COL_LENGTH(N'dbo.TDARCustomer', N'PaymentType') AS PaymentTypeLength,
  COL_LENGTH(N'dbo.TDARCustomer', N'CreditDays') AS CreditDaysLength,
  COL_LENGTH(N'dbo.TDARCustomer', N'CreditLimit') AS CreditLimitLength,
  COL_LENGTH(N'dbo.TDARCustomer', N'SalespersonEmployeeID') AS SalespersonEmployeeIDLength,
  COL_LENGTH(N'dbo.TDARCustomer', N'TaxType') AS TaxTypeLength;
