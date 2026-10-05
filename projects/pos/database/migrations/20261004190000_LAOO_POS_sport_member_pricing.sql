SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Optional LAOO_SPORT linkage. Existing POS sales remain unchanged.
IF OBJECT_ID(N'dbo.TDPOSale',N'U') IS NULL
 THROW 57601,N'POS sale table is required.',1;
IF COL_LENGTH(N'dbo.TDPOSale',N'SportMemberID') IS NULL
 ALTER TABLE dbo.TDPOSale ADD SportMemberID bigint NULL;
IF COL_LENGTH(N'dbo.TDPOSale',N'SportLevelIDSnapshot') IS NULL
 ALTER TABLE dbo.TDPOSale ADD SportLevelIDSnapshot bigint NULL;
IF COL_LENGTH(N'dbo.TDPOSale',N'SportPriceLevelCodeSnapshot') IS NULL
 ALTER TABLE dbo.TDPOSale ADD SportPriceLevelCodeSnapshot nvarchar(30) NULL;
