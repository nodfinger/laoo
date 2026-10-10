SET NOCOUNT ON;
SET XACT_ABORT ON;
ALTER TABLE dbo.TDPTEntitlement ADD PriceSnapshot decimal(18,2) NOT NULL CONSTRAINT DF_TDPTEntitlement_Price DEFAULT 0;
ALTER TABLE dbo.TDPTEntitlement ADD PaymentMethod nvarchar(20) NULL, PaymentReference nvarchar(100) NULL;
GO
ALTER TABLE dbo.TDPTEntitlement ADD CONSTRAINT CK_TDPTEntitlement_Payment CHECK(
 (SaleID IS NOT NULL AND PaymentMethod IS NULL AND PaymentReference IS NULL)
 OR (SaleID IS NULL AND PaymentMethod IN(N'CASH',N'TRANSFER') AND PaymentReference IS NOT NULL));
CREATE UNIQUE INDEX UX_TDPTEntitlement_SalePackage ON dbo.TDPTEntitlement(CompanyID,SaleID,PackageID) WHERE SaleID IS NOT NULL;
GO
