SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADResident', N'U') IS NULL THROW 53000, N'TDADResident is required.', 1;
IF OBJECT_ID(N'dbo.TDADVillageHouse', N'U') IS NULL THROW 53001, N'TDADVillageHouse is required.', 1;
IF COL_LENGTH(N'dbo.TDADResident', N'HouseID') IS NULL ALTER TABLE dbo.TDADResident ADD HouseID bigint NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.TDADResident') AND name=N'RoomID' AND is_nullable=0) ALTER TABLE dbo.TDADResident ALTER COLUMN RoomID bigint NULL;
IF COL_LENGTH(N'dbo.TDADVillageResident', N'ResidentID') IS NULL ALTER TABLE dbo.TDADVillageResident ADD ResidentID bigint NULL;EXEC(N'IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N''FK_TDADResident_House'')
    ALTER TABLE dbo.TDADResident ADD CONSTRAINT FK_TDADResident_House FOREIGN KEY(CompanyID,HouseID) REFERENCES dbo.TDADVillageHouse(CompanyID,HouseID);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N''CK_TDADResident_ExactlyOneLocation'')
    ALTER TABLE dbo.TDADResident ADD CONSTRAINT CK_TDADResident_ExactlyOneLocation CHECK ((RoomID IS NOT NULL AND HouseID IS NULL) OR (RoomID IS NULL AND HouseID IS NOT NULL));
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N''FK_TDADVillageResident_Resident'')
    ALTER TABLE dbo.TDADVillageResident ADD CONSTRAINT FK_TDADVillageResident_Resident FOREIGN KEY(CompanyID,ResidentID) REFERENCES dbo.TDADResident(CompanyID,ResidentID);
IF EXISTS (SELECT 1 FROM dbo.TDADResident WHERE IsActive=1 GROUP BY CompanyID,PersonID HAVING COUNT_BIG(1)>1) THROW 53002, N''ACTIVE_RESIDENT_DUPLICATE_EXISTS'', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADVillageResident V LEFT JOIN dbo.TDADResident R ON R.CompanyID=V.CompanyID AND R.ResidentID=V.ResidentID WHERE V.ResidentID IS NOT NULL AND R.ResidentID IS NULL) THROW 53003, N''INVALID_VILLAGE_RESIDENT_MAPPING'', 1;
DECLARE @Village TABLE(VillageResidentID bigint PRIMARY KEY,CompanyID bigint,HouseID bigint,PersonID bigint,StartDate date,EndDate date,IsActive bit);
INSERT @Village SELECT VillageResidentID,CompanyID,HouseID,PersonID,StartDate,EndDate,IsActive FROM dbo.TDADVillageResident WHERE ResidentID IS NULL;
IF EXISTS (SELECT 1 FROM @Village V JOIN dbo.TDADResident R ON R.CompanyID=V.CompanyID AND R.PersonID=V.PersonID AND R.IsActive=1 WHERE V.IsActive=1) THROW 53004, N''VILLAGE_RESIDENT_CONFLICTS_WITH_ACTIVE_RESIDENT'', 1;
INSERT dbo.TDADResident(CompanyID,PersonID,RoomID,HouseID,StartDate,EndDate,IsActive,CreateBy) SELECT CompanyID,PersonID,NULL,HouseID,StartDate,EndDate,IsActive,NULL FROM @Village;
UPDATE V SET ResidentID=R.ResidentID FROM dbo.TDADVillageResident V JOIN dbo.TDADResident R ON R.CompanyID=V.CompanyID AND R.PersonID=V.PersonID AND R.HouseID=V.HouseID AND R.RoomID IS NULL AND R.StartDate=V.StartDate WHERE V.ResidentID IS NULL;
IF EXISTS (SELECT 1 FROM dbo.TDADVillageResident WHERE ResidentID IS NULL) THROW 53005, N''VILLAGE_RESIDENT_MAPPING_FAILED'', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N''dbo.TDADResident'') AND name=N''UX_TDADResident_Company_ActivePerson'') CREATE UNIQUE INDEX UX_TDADResident_Company_ActivePerson ON dbo.TDADResident(CompanyID,PersonID) WHERE IsActive=1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N''dbo.TDADResident'') AND name=N''IX_TDADResident_Company_House'') CREATE INDEX IX_TDADResident_Company_House ON dbo.TDADResident(CompanyID,HouseID,IsActive,PersonID);');
