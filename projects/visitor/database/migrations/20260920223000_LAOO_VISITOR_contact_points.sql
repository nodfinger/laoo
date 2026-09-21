/* LAOO_VISITOR: contact points and the point snapshot used by Check-in.
   This migration is intentionally additive and idempotent. */
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMVisitorContactPoint', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorContactPoint
    (
        VisitorContactPointID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorContactPoint PRIMARY KEY,
        CompanyID bigint NOT NULL,
        BranchID bigint NOT NULL,
        ContactPointCode varchar(30) NOT NULL,
        ContactPointName nvarchar(200) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMVisitorContactPoint_IsActive DEFAULT (1),
        CreateDate datetime2(0) NOT NULL CONSTRAINT DF_TDTMVisitorContactPoint_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy bigint NOT NULL,
        UpdateDate datetime2(0) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDTMVisitorContactPoint_Company_Code UNIQUE (CompanyID, ContactPointCode),
        CONSTRAINT UQ_TDTMVisitorContactPoint_Company_ID UNIQUE (CompanyID, VisitorContactPointID)
    );
END;

IF OBJECT_ID(N'dbo.TDTMVisitorContactPointEmployee', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorContactPointEmployee
    (
        VisitorContactPointEmployeeID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorContactPointEmployee PRIMARY KEY,
        CompanyID bigint NOT NULL,
        VisitorContactPointID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMVisitorContactPointEmployee_IsActive DEFAULT (1),
        CreateDate datetime2(0) NOT NULL CONSTRAINT DF_TDTMVisitorContactPointEmployee_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy bigint NOT NULL,
        UpdateDate datetime2(0) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMVisitorContactPointEmployee_Point FOREIGN KEY (CompanyID, VisitorContactPointID)
            REFERENCES dbo.TDTMVisitorContactPoint (CompanyID, VisitorContactPointID)
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMVisitorContactPointEmployee') AND name=N'UX_TDTMVisitorContactPointEmployee_ActiveEmployee')
    CREATE UNIQUE INDEX UX_TDTMVisitorContactPointEmployee_ActiveEmployee
        ON dbo.TDTMVisitorContactPointEmployee(CompanyID, EmployeeID) WHERE IsActive=1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMVisitorContactPointEmployee') AND name=N'UX_TDTMVisitorContactPointEmployee_ActivePointEmployee')
    CREATE UNIQUE INDEX UX_TDTMVisitorContactPointEmployee_ActivePointEmployee
        ON dbo.TDTMVisitorContactPointEmployee(VisitorContactPointID, EmployeeID) WHERE IsActive=1;

IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'VisitorContactPointID') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD VisitorContactPointID bigint NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'ContactPointNameSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD ContactPointNameSnapshot nvarchar(200) NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMVisitorVisit') AND name=N'IX_TDTMVisitorVisit_Company_ContactPoint_Status')
    CREATE INDEX IX_TDTMVisitorVisit_Company_ContactPoint_Status
        ON dbo.TDTMVisitorVisit(CompanyID, VisitorContactPointID, StatusCode);

COMMIT TRANSACTION;
