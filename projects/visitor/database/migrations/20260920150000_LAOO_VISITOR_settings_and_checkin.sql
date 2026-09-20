SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMVisitorSystemSettingVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorSystemSettingVersion
    (
        VisitorSystemSettingVersionID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorSystemSettingVersion PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ProjectID bigint NOT NULL,
        VersionNo int NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        AllowManualEntry bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Manual DEFAULT(1),
        AllowCameraCapture bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Camera DEFAULT(1),
        AllowNationalIdReader bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Reader DEFAULT(0),
        RequireVisitorPhone bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Phone DEFAULT(0),
        RequireHostEmployee bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Host DEFAULT(1),
        RequireVisitPurpose bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Purpose DEFAULT(1),
        RequireCardImage bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Image DEFAULT(1),
        RequireNationalIdNumber bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_IdNumber DEFAULT(0),
        RequireNationalIdExpiry bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_IdExpiry DEFAULT(0),
        RequireCheckOut bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_CheckOut DEFAULT(1),
        RetentionPolicyCode varchar(30) NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Retention DEFAULT('COMPANY_POLICY'),
        IsActive bit NOT NULL CONSTRAINT DF_TDTMVisitorSetting_Active DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorSetting_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDTMVisitorSetting_Version UNIQUE(CompanyID, VersionNo),
        CONSTRAINT UQ_TDTMVisitorSetting_Effective UNIQUE(CompanyID, EffectiveFrom),
        CONSTRAINT CK_TDTMVisitorSetting_Reader CHECK(AllowNationalIdReader=0)
    );
    CREATE INDEX IX_TDTMVisitorSetting_ActiveDate
        ON dbo.TDTMVisitorSystemSettingVersion(CompanyID, IsActive, EffectiveFrom DESC);
END;

IF OBJECT_ID(N'dbo.TDTMVisitorVisit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorVisit
    (
        VisitorVisitID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorVisit PRIMARY KEY,
        CompanyID bigint NOT NULL,
        BranchID bigint NOT NULL,
        VisitorName nvarchar(200) NOT NULL,
        Phone nvarchar(50) NULL,
        NationalIdMasked nvarchar(30) NULL,
        NationalIdHash varbinary(32) NULL,
        NationalIdExpiryDate date NULL,
        HostEmployeeID bigint NULL,
        VisitPurpose nvarchar(500) NULL,
        CaptureMethod varchar(30) NOT NULL,
        StatusCode varchar(30) NOT NULL CONSTRAINT DF_TDTMVisitorVisit_Status DEFAULT('CHECKED_IN'),
        CheckedInDate datetime2(3) NOT NULL,
        CheckedOutDate datetime2(3) NULL,
        SettingsVersionID bigint NOT NULL,
        RequestId nvarchar(100) NOT NULL,
        SettingsSnapshotJson nvarchar(max) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorVisit_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDTMVisitorVisit_Request UNIQUE(CompanyID, RequestId),
        CONSTRAINT CK_TDTMVisitorVisit_Method CHECK(CaptureMethod IN('MANUAL_ENTRY','CAMERA_CAPTURE','NATIONAL_ID_READER')),
        CONSTRAINT CK_TDTMVisitorVisit_Status CHECK(StatusCode IN('PENDING_EVIDENCE','CHECKED_IN','CHECKED_OUT','CANCELLED'))
    );
    CREATE INDEX IX_TDTMVisitorVisit_Inside
        ON dbo.TDTMVisitorVisit(CompanyID, BranchID, StatusCode, CheckedInDate DESC);
    CREATE INDEX IX_TDTMVisitorVisit_NationalId
        ON dbo.TDTMVisitorVisit(CompanyID, NationalIdHash);
END;

IF OBJECT_ID(N'dbo.TDTMVisitorVisitImage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorVisitImage
    (
        VisitorVisitImageID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorVisitImage PRIMARY KEY,
        CompanyID bigint NOT NULL,
        VisitorVisitID bigint NOT NULL,
        SideCode varchar(10) NOT NULL,
        FileRelativePath nvarchar(500) NOT NULL,
        OriginalFileName nvarchar(260) NULL,
        ContentType varchar(100) NOT NULL,
        ContentLength bigint NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorVisitImage_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        CONSTRAINT FK_TDTMVisitorVisitImage_Visit FOREIGN KEY(VisitorVisitID) REFERENCES dbo.TDTMVisitorVisit(VisitorVisitID),
        CONSTRAINT UQ_TDTMVisitorVisitImage_Side UNIQUE(VisitorVisitID, SideCode),
        CONSTRAINT CK_TDTMVisitorVisitImage_Side CHECK(SideCode IN('FRONT','BACK'))
    );
END;

IF OBJECT_ID(N'dbo.TDTMVisitorSystemSettingAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorSystemSettingAudit
    (
        VisitorSystemSettingAuditID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorSystemSettingAudit PRIMARY KEY,
        CompanyID bigint NOT NULL,
        SettingVersionID bigint NOT NULL,
        BeforeJson nvarchar(max) NULL,
        AfterJson nvarchar(max) NOT NULL,
        Reason nvarchar(1000) NOT NULL,
        ActorUserID bigint NOT NULL,
        CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMVisitorSettingAudit_Correlation DEFAULT(NEWID()),
        OccurredDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorSettingAudit_Occurred DEFAULT(SYSUTCDATETIME())
    );
END;

COMMIT TRANSACTION;
