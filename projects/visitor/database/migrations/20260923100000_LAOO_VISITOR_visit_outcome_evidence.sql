SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'VisitOutcomeCode') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD VisitOutcomeCode varchar(20) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'CheckoutReasonCode') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD CheckoutReasonCode varchar(40) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'CheckoutNote') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD CheckoutNote nvarchar(1000) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'CheckedOutByUserID') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD CheckedOutByUserID bigint NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'CheckedOutByNameSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD CheckedOutByNameSnapshot nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'ResultRecordedDate') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD ResultRecordedDate datetime2(3) NULL;

IF OBJECT_ID(N'dbo.TDTMVisitorVisitNote', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorVisitNote
    (
        VisitorVisitNoteID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorVisitNote PRIMARY KEY,
        CompanyID bigint NOT NULL,
        VisitorVisitID bigint NOT NULL,
        NoteStageCode varchar(20) NOT NULL,
        NoteText nvarchar(2000) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorVisitNote_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NOT NULL,
        CONSTRAINT FK_TDTMVisitorVisitNote_Visit FOREIGN KEY(VisitorVisitID) REFERENCES dbo.TDTMVisitorVisit(VisitorVisitID),
        CONSTRAINT CK_TDTMVisitorVisitNote_Stage CHECK(NoteStageCode IN('CHECKIN','CHECKOUT','GENERAL'))
    );
    CREATE INDEX IX_TDTMVisitorVisitNote_Visit ON dbo.TDTMVisitorVisitNote(CompanyID,VisitorVisitID,CreateDate);
END;

IF OBJECT_ID(N'dbo.TDTMVisitorVisitAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorVisitAudit
    (
        VisitorVisitAuditID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorVisitAudit PRIMARY KEY,
        CompanyID bigint NOT NULL,
        VisitorVisitID bigint NOT NULL,
        FromStatusCode varchar(30) NULL,
        ToStatusCode varchar(30) NOT NULL,
        OutcomeCode varchar(20) NULL,
        ReasonCode varchar(40) NULL,
        NoteText nvarchar(1000) NULL,
        ActorUserID bigint NOT NULL,
        ActorNameSnapshot nvarchar(200) NULL,
        OccurredDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorVisitAudit_OccurredDate DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT FK_TDTMVisitorVisitAudit_Visit FOREIGN KEY(VisitorVisitID) REFERENCES dbo.TDTMVisitorVisit(VisitorVisitID)
    );
    CREATE INDEX IX_TDTMVisitorVisitAudit_Visit ON dbo.TDTMVisitorVisitAudit(CompanyID,VisitorVisitID,OccurredDate);
END;

IF COL_LENGTH(N'dbo.TDTMVisitorVisitImage', N'EvidenceType') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisitImage ADD EvidenceType varchar(20) NOT NULL CONSTRAINT DF_TDTMVisitorVisitImage_EvidenceType DEFAULT('DOCUMENT');
IF COL_LENGTH(N'dbo.TDTMVisitorVisitImage', N'CaptureStage') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisitImage ADD CaptureStage varchar(20) NOT NULL CONSTRAINT DF_TDTMVisitorVisitImage_CaptureStage DEFAULT('CHECKIN');

EXEC sys.sp_executesql N'
UPDATE dbo.TDTMVisitorVisitImage
SET EvidenceType=''DOCUMENT'',CaptureStage=''CHECKIN''
WHERE EvidenceType IS NULL OR CaptureStage IS NULL;';

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_TDTMVisitorVisitImage_Side' AND parent_object_id=OBJECT_ID(N'dbo.TDTMVisitorVisitImage'))
    ALTER TABLE dbo.TDTMVisitorVisitImage DROP CONSTRAINT UQ_TDTMVisitorVisitImage_Side;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_TDTMVisitorVisitImage_EvidenceType' AND parent_object_id=OBJECT_ID(N'dbo.TDTMVisitorVisitImage'))
    EXEC sys.sp_executesql N'ALTER TABLE dbo.TDTMVisitorVisitImage ADD CONSTRAINT CK_TDTMVisitorVisitImage_EvidenceType CHECK(EvidenceType IN(''DOCUMENT'',''VEHICLE'',''OTHER''))';
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_TDTMVisitorVisitImage_CaptureStage' AND parent_object_id=OBJECT_ID(N'dbo.TDTMVisitorVisitImage'))
    EXEC sys.sp_executesql N'ALTER TABLE dbo.TDTMVisitorVisitImage ADD CONSTRAINT CK_TDTMVisitorVisitImage_CaptureStage CHECK(CaptureStage IN(''CHECKIN'',''CHECKOUT''))';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'UX_TDTMVisitorVisitImage_DocumentSide' AND object_id=OBJECT_ID(N'dbo.TDTMVisitorVisitImage'))
    EXEC sys.sp_executesql N'CREATE UNIQUE INDEX UX_TDTMVisitorVisitImage_DocumentSide
        ON dbo.TDTMVisitorVisitImage(VisitorVisitID,CaptureStage,SideCode)
        WHERE EvidenceType=''DOCUMENT'' AND SideCode IS NOT NULL';

COMMIT TRANSACTION;
