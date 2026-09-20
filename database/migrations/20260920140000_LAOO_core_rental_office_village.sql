SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'BusinessTypeCode') IS NULL
    THROW 52900, 'BusinessTypeCode is required before extending company types.', 1;

DECLARE @constraint sysname;
SELECT @constraint = kc.name
FROM sys.check_constraints kc
WHERE kc.parent_object_id = OBJECT_ID(N'dbo.TDSTCompanySetUp')
  AND kc.name = N'CK_TDSTCompanySetUp_BusinessTypeCode';
IF @constraint IS NOT NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.TDSTCompanySetUp DROP CONSTRAINT CK_TDSTCompanySetUp_BusinessTypeCode');
END;
ALTER TABLE dbo.TDSTCompanySetUp WITH CHECK ADD CONSTRAINT CK_TDSTCompanySetUp_BusinessTypeCode
    CHECK (BusinessTypeCode IN (N'COMPANY',N'DORMITORY',N'SERVICE_CENTER',N'RENTAL_OFFICE',N'VILLAGE'));

IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMasterGroup WHERE GroupCode=N'012')
    THROW 52901, 'Master group 012 is required before extending company types.', 1;

MERGE dbo.TDSTMasterCont AS target
USING (VALUES
    (N'012',N'RENTAL_OFFICE',N'สำนักงานเช่า',40),
    (N'012',N'VILLAGE',N'หมู่บ้าน',50)
) AS source(GroupCode,Code,Name,Seq)
ON target.GroupCode=source.GroupCode AND target.Code=source.Code
WHEN MATCHED THEN UPDATE SET Name=source.Name, Seq=source.Seq, IsActive=1
WHEN NOT MATCHED THEN INSERT(GroupCode,Code,Name,Seq,IsActive) VALUES(source.GroupCode,source.Code,source.Name,source.Seq,1);

IF OBJECT_ID(N'dbo.TDADRentalOfficeTenant',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADRentalOfficeTenant
    (
        TenantID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADRentalOfficeTenant PRIMARY KEY,
        CompanyID bigint NOT NULL,
        RoomID bigint NOT NULL,
        CustomerID bigint NULL,
        TenantCompanyName nvarchar(200) NOT NULL,
        TenantNameSnapshot nvarchar(200) NOT NULL,
        StartDate date NOT NULL,
        EndDate date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADRentalOfficeTenant_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADRentalOfficeTenant_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADRentalOfficeTenant_Company_ID UNIQUE(CompanyID,TenantID),
        CONSTRAINT FK_TDADRentalOfficeTenant_Room FOREIGN KEY(CompanyID,RoomID) REFERENCES dbo.TDADRoom(CompanyID,RoomID),
        CONSTRAINT CK_TDADRentalOfficeTenant_Date CHECK(EndDate IS NULL OR EndDate>=StartDate)
    );
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'UX_TDADRentalOfficeTenant_ActiveRoom' AND object_id=OBJECT_ID(N'dbo.TDADRentalOfficeTenant'))
    CREATE UNIQUE INDEX UX_TDADRentalOfficeTenant_ActiveRoom ON dbo.TDADRentalOfficeTenant(CompanyID,RoomID) WHERE IsActive=1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'IX_TDADRentalOfficeTenant_Company_Active' AND object_id=OBJECT_ID(N'dbo.TDADRentalOfficeTenant'))
    CREATE INDEX IX_TDADRentalOfficeTenant_Company_Active ON dbo.TDADRentalOfficeTenant(CompanyID,IsActive,RoomID);

IF OBJECT_ID(N'dbo.TDADRentalOfficeTenantContact',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADRentalOfficeTenantContact
    (
        TenantContactID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADRentalOfficeTenantContact PRIMARY KEY,
        CompanyID bigint NOT NULL,
        TenantID bigint NOT NULL,
        PersonID bigint NULL,
        ContactName nvarchar(200) NOT NULL,
        Phone nvarchar(50) NULL,
        Email nvarchar(320) NULL,
        IsPrimary bit NOT NULL CONSTRAINT DF_TDADRentalOfficeTenantContact_IsPrimary DEFAULT(0),
        IsActive bit NOT NULL CONSTRAINT DF_TDADRentalOfficeTenantContact_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADRentalOfficeTenantContact_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDADRentalOfficeTenantContact_Tenant FOREIGN KEY(CompanyID,TenantID) REFERENCES dbo.TDADRentalOfficeTenant(CompanyID,TenantID),
        CONSTRAINT FK_TDADRentalOfficeTenantContact_Person FOREIGN KEY(CompanyID,PersonID) REFERENCES dbo.TDADPerson(CompanyID,PersonID)
    );
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'IX_TDADRentalOfficeTenantContact_Company_Tenant' AND object_id=OBJECT_ID(N'dbo.TDADRentalOfficeTenantContact'))
    CREATE INDEX IX_TDADRentalOfficeTenantContact_Company_Tenant ON dbo.TDADRentalOfficeTenantContact(CompanyID,TenantID,IsActive);

IF OBJECT_ID(N'dbo.TDADVillageLane',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADVillageLane
    (
        LaneID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADVillageLane PRIMARY KEY,
        CompanyID bigint NOT NULL,
        LaneType nvarchar(20) NOT NULL,
        LaneCode nvarchar(50) NOT NULL,
        LaneName nvarchar(200) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADVillageLane_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADVillageLane_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADVillageLane_Company_ID UNIQUE(CompanyID,LaneID),
        CONSTRAINT UQ_TDADVillageLane_Company_Type_Code UNIQUE(CompanyID,LaneType,LaneCode),
        CONSTRAINT CK_TDADVillageLane_Type CHECK(LaneType IN(N'SOI',N'JUNCTION'))
    );
END;

IF OBJECT_ID(N'dbo.TDADVillageHouse',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADVillageHouse
    (
        HouseID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADVillageHouse PRIMARY KEY,
        CompanyID bigint NOT NULL,
        LaneID bigint NOT NULL,
        HouseNo nvarchar(100) NOT NULL,
        AddressText nvarchar(500) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADVillageHouse_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADVillageHouse_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADVillageHouse_Company_ID UNIQUE(CompanyID,HouseID),
        CONSTRAINT UQ_TDADVillageHouse_Company_Lane_House UNIQUE(CompanyID,LaneID,HouseNo),
        CONSTRAINT FK_TDADVillageHouse_Lane FOREIGN KEY(CompanyID,LaneID) REFERENCES dbo.TDADVillageLane(CompanyID,LaneID)
    );
END;

IF OBJECT_ID(N'dbo.TDADVillageResident',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADVillageResident
    (
        VillageResidentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADVillageResident PRIMARY KEY,
        CompanyID bigint NOT NULL,
        HouseID bigint NOT NULL,
        PersonID bigint NOT NULL,
        StartDate date NOT NULL,
        EndDate date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADVillageResident_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADVillageResident_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDADVillageResident_House FOREIGN KEY(CompanyID,HouseID) REFERENCES dbo.TDADVillageHouse(CompanyID,HouseID),
        CONSTRAINT FK_TDADVillageResident_Person FOREIGN KEY(CompanyID,PersonID) REFERENCES dbo.TDADPerson(CompanyID,PersonID),
        CONSTRAINT CK_TDADVillageResident_Date CHECK(EndDate IS NULL OR EndDate>=StartDate)
    );
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'UX_TDADVillageResident_ActivePersonHouse' AND object_id=OBJECT_ID(N'dbo.TDADVillageResident'))
    CREATE UNIQUE INDEX UX_TDADVillageResident_ActivePersonHouse ON dbo.TDADVillageResident(CompanyID,HouseID,PersonID) WHERE IsActive=1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'IX_TDADVillageResident_Company_House' AND object_id=OBJECT_ID(N'dbo.TDADVillageResident'))
    CREATE INDEX IX_TDADVillageResident_Company_House ON dbo.TDADVillageResident(CompanyID,HouseID,IsActive);

COMMIT TRANSACTION;