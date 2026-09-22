SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADResident', N'U') IS NULL
    THROW 53010, N'TDADResident is required.', 1;

IF COL_LENGTH(N'dbo.TDADResident', N'HouseID') IS NULL
    ALTER TABLE dbo.TDADResident ADD HouseID bigint NULL;

IF OBJECT_ID(N'dbo.TDADVillageHouse', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name=N'FK_TDADResident_House'
      AND parent_object_id=OBJECT_ID(N'dbo.TDADResident')
)
BEGIN
    ALTER TABLE dbo.TDADResident
        ADD CONSTRAINT FK_TDADResident_House
        FOREIGN KEY(CompanyID,HouseID)
        REFERENCES dbo.TDADVillageHouse(CompanyID,HouseID);
END;

