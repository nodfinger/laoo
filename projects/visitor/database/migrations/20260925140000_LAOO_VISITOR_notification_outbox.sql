SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMVisitorNotificationOutbox', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorNotificationOutbox
    (
        VisitorNotificationOutboxID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorNotificationOutbox PRIMARY KEY,
        CompanyID bigint NOT NULL,
        VisitorVisitID bigint NOT NULL,
        RecipientHostType varchar(30) NOT NULL,
        RecipientUserID bigint NULL,
        RecipientPersonID bigint NULL,
        ChannelCode varchar(20) NOT NULL,
        StatusCode varchar(20) NOT NULL,
        NotificationID bigint NULL,
        IdempotencyKey nvarchar(200) NOT NULL,
        PayloadSnapshotJson nvarchar(max) NOT NULL,
        LastErrorMessage nvarchar(2000) NULL,
        AttemptCount int NOT NULL
            CONSTRAINT DF_TDTMVisitorNotificationOutbox_AttemptCount DEFAULT(0),
        FirstAttemptDate datetime2(3) NULL,
        CompletedDate datetime2(3) NULL,
        CreateDate datetime2(3) NOT NULL
            CONSTRAINT DF_TDTMVisitorNotificationOutbox_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NOT NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        CONSTRAINT UQ_TDTMVisitorNotificationOutbox_CompanyKey
            UNIQUE(CompanyID, IdempotencyKey),
        CONSTRAINT FK_TDTMVisitorNotificationOutbox_Visit
            FOREIGN KEY(VisitorVisitID) REFERENCES dbo.TDTMVisitorVisit(VisitorVisitID),
        CONSTRAINT CK_TDTMVisitorNotificationOutbox_Channel
            CHECK(ChannelCode IN('IN_APP')),
        CONSTRAINT CK_TDTMVisitorNotificationOutbox_Status
            CHECK(StatusCode IN('PENDING','SENT','FAILED','NO_CHANNEL'))
    );

    CREATE INDEX IX_TDTMVisitorNotificationOutbox_Dispatch
        ON dbo.TDTMVisitorNotificationOutbox(CompanyID, StatusCode, CreateDate);
    CREATE INDEX IX_TDTMVisitorNotificationOutbox_Visit
        ON dbo.TDTMVisitorNotificationOutbox(CompanyID, VisitorVisitID);
END;

IF OBJECT_ID(N'dbo.TDTMVisitorNotificationOutboxAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorNotificationOutboxAudit
    (
        VisitorNotificationOutboxAuditID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorNotificationOutboxAudit PRIMARY KEY,
        CompanyID bigint NOT NULL,
        VisitorNotificationOutboxID bigint NOT NULL,
        FromStatusCode varchar(20) NULL,
        ToStatusCode varchar(20) NOT NULL,
        DetailText nvarchar(2000) NULL,
        ActorUserID bigint NOT NULL,
        ActorNameSnapshot nvarchar(200) NULL,
        OccurredDate datetime2(3) NOT NULL
            CONSTRAINT DF_TDTMVisitorNotificationOutboxAudit_OccurredDate DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT FK_TDTMVisitorNotificationOutboxAudit_Outbox
            FOREIGN KEY(VisitorNotificationOutboxID)
            REFERENCES dbo.TDTMVisitorNotificationOutbox(VisitorNotificationOutboxID)
    );

    CREATE INDEX IX_TDTMVisitorNotificationOutboxAudit_Outbox
        ON dbo.TDTMVisitorNotificationOutboxAudit
            (CompanyID, VisitorNotificationOutboxID, OccurredDate);
END;

COMMIT TRANSACTION;
