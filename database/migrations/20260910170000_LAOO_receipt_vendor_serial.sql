-- Approved receipt integration. Transaction, application lock and ledger are owned by run-migrations.ps1.
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDAPVendor',N'U') IS NULL
 THROW 52710,'Run the Core vendor migration first.',1;
ALTER TABLE dbo.TDIVStockReceipt ADD
 VendorID bigint NULL,
 VendorCode nvarchar(50) NULL,
 VendorName nvarchar(200) NULL,
 DeliveredBy nvarchar(200) NULL;
GO
ALTER TABLE dbo.TDIVStockReceipt WITH CHECK ADD CONSTRAINT FK_TDIVStockReceipt_Vendor
 FOREIGN KEY(CompanyID,VendorID) REFERENCES dbo.TDAPVendor(CompanyID,VendorID);
CREATE INDEX IX_TDIVStockReceipt_Vendor ON dbo.TDIVStockReceipt(CompanyID,VendorID);
ALTER TABLE dbo.TDIVStockReceiptDetail ADD SerialSourceCode varchar(20) NOT NULL
 CONSTRAINT DF_TDIVStockReceiptDetail_SerialSource DEFAULT('FACTORY') WITH VALUES;
GO
ALTER TABLE dbo.TDIVStockReceiptDetail WITH CHECK ADD CONSTRAINT CK_TDIVStockReceiptDetail_SerialSource
 CHECK(SerialSourceCode IN('FACTORY','INTERNAL'));
-- Existing receipts keep their original data. No vendor assignment or stock movement.
