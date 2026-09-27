SET XACT_ABORT ON;
-- Retain legacy branch-scoped codes and IDs; permit Company-owned buildings.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.TDADBuilding') AND name=N'BranchID' AND is_nullable=0)
BEGIN
    DROP INDEX UX_TDADBuilding_BranchCode ON dbo.TDADBuilding;
    ALTER TABLE dbo.TDADBuilding ALTER COLUMN BranchID bigint NULL;
    CREATE UNIQUE INDEX UX_TDADBuilding_BranchCode ON dbo.TDADBuilding(BranchID,BuildingCode) WHERE BranchID IS NOT NULL;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADBuilding') AND name=N'UX_TDADBuilding_CompanyCode')
    CREATE UNIQUE INDEX UX_TDADBuilding_CompanyCode ON dbo.TDADBuilding(CompanyID,BuildingCode) WHERE BranchID IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADBuilding') AND name=N'UQ_TDADBuilding_CompanyID')
    CREATE UNIQUE INDEX UQ_TDADBuilding_CompanyID ON dbo.TDADBuilding(CompanyID,BuildingID);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADFloor') AND name=N'UQ_TDADFloor_BuildingID')
    CREATE UNIQUE INDEX UQ_TDADFloor_BuildingID ON dbo.TDADFloor(BuildingID,FloorID);
GO
IF OBJECT_ID(N'dbo.TDADRoom',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADRoom
    (
        RoomID bigint IDENTITY PRIMARY KEY,
        CompanyID bigint NOT NULL,
        BuildingID bigint NOT NULL,
        FloorID bigint NOT NULL,
        RoomCode nvarchar(20) NOT NULL,
        RoomNameTH nvarchar(200) NOT NULL,
        RoomTypeCode nvarchar(30) NOT NULL,
        Description nvarchar(1000) NULL,
        IsActive bit NOT NULL DEFAULT(1),
        CreateDate datetime2 NOT NULL DEFAULT(SYSUTCDATETIME()),
        CreateBy nvarchar(100) NULL,
        UpdateDate datetime2 NULL,
        UpdateBy nvarchar(100) NULL,
        CONSTRAINT FK_TDADRoom_Building FOREIGN KEY(CompanyID,BuildingID) REFERENCES dbo.TDADBuilding(CompanyID,BuildingID),
        CONSTRAINT FK_TDADRoom_Floor FOREIGN KEY(BuildingID,FloorID) REFERENCES dbo.TDADFloor(BuildingID,FloorID),
        CONSTRAINT UQ_TDADRoom_Code UNIQUE(CompanyID,FloorID,RoomCode),
        CONSTRAINT UQ_TDADRoom_CompanyID UNIQUE(CompanyID,RoomID),
        CONSTRAINT CK_TDADRoom_Type CHECK(RoomTypeCode IN(N'RESIDENTIAL',N'OFFICE',N'COMMON',N'OTHER'))
    );
END;
