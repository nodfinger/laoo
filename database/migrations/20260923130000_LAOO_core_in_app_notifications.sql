IF OBJECT_ID(N'dbo.TDADPersonNotificationPreference',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADPersonNotificationPreference
    (
        CompanyID bigint NOT NULL,
        PersonID bigint NOT NULL,
        NotifyInSystem bit NOT NULL CONSTRAINT DF_TDADPersonNotificationPreference_Notify DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADPersonNotificationPreference_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT PK_TDADPersonNotificationPreference PRIMARY KEY(CompanyID,PersonID),
        CONSTRAINT FK_TDADPersonNotificationPreference_Person FOREIGN KEY(CompanyID,PersonID) REFERENCES dbo.TDADPerson(CompanyID,PersonID)
    );
END;

IF OBJECT_ID(N'dbo.TDADNotification',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADNotification
    (
        NotificationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADNotification PRIMARY KEY,
        CompanyID bigint NOT NULL,
        RecipientUserID bigint NULL,
        RecipientPersonID bigint NULL,
        SourceProject nvarchar(50) NOT NULL,
        SourceType nvarchar(80) NOT NULL,
        SourceID bigint NULL,
        Title nvarchar(200) NOT NULL,
        Message nvarchar(2000) NOT NULL,
        PayloadJson nvarchar(max) NULL,
        IdempotencyKey nvarchar(200) NOT NULL,
        StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDADNotification_Status DEFAULT(N'PENDING'),
        ErrorMessage nvarchar(1000) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADNotification_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        SentDate datetime2(3) NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDADNotification_Status CHECK(StatusCode IN(N'PENDING',N'SENT',N'FAILED',N'NO_CHANNEL'))
    );
END;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADNotification') AND name=N'UX_TDADNotification_Company_Idempotency')
    CREATE UNIQUE INDEX UX_TDADNotification_Company_Idempotency ON dbo.TDADNotification(CompanyID,SourceProject,IdempotencyKey);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADNotification') AND name=N'IX_TDADNotification_Recipient')
    CREATE INDEX IX_TDADNotification_Recipient ON dbo.TDADNotification(CompanyID,RecipientUserID,CreateDate DESC);

IF OBJECT_ID(N'dbo.TDADNotificationRead',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADNotificationRead
    (
        CompanyID bigint NOT NULL,
        NotificationID bigint NOT NULL,
        UserID bigint NOT NULL,
        ReadDate datetime2(3) NOT NULL CONSTRAINT DF_TDADNotificationRead_Date DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT PK_TDADNotificationRead PRIMARY KEY(CompanyID,NotificationID,UserID),
        CONSTRAINT FK_TDADNotificationRead_Notification FOREIGN KEY(NotificationID) REFERENCES dbo.TDADNotification(NotificationID)
    );
END;

IF OBJECT_ID(N'dbo.TDADNotificationAudit',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADNotificationAudit
    (
        NotificationAuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADNotificationAudit PRIMARY KEY,
        CompanyID bigint NOT NULL,
        NotificationID bigint NOT NULL,
        StatusCode nvarchar(20) NOT NULL,
        Detail nvarchar(1000) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADNotificationAudit_Date DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL
    );
END;
