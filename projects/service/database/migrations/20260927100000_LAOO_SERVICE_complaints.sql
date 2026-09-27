/* Service complaints: additive and idempotent. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADServiceComplaint', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADServiceComplaint
    (
        ComplaintID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADServiceComplaint PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ComplaintNo nvarchar(30) NOT NULL,
        ComplainantPersonID bigint NULL,
        ComplainantNameSnapshot nvarchar(200) NOT NULL,
        ComplainantPhoneSnapshot nvarchar(50) NULL,
        ComplainantEmailSnapshot nvarchar(320) NULL,
        LocationSnapshot nvarchar(500) NULL,
        Subject nvarchar(200) NOT NULL,
        Detail nvarchar(2000) NOT NULL,
        StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDADServiceComplaint_Status DEFAULT (N'NEW'),
        RequestDate datetime2 NOT NULL CONSTRAINT DF_TDADServiceComplaint_RequestDate DEFAULT (SYSUTCDATETIME()),
        StartedDate datetime2 NULL,
        StartedBy bigint NULL,
        CompletedDate datetime2 NULL,
        CompletedBy bigint NULL,
        ResolutionDetail nvarchar(2000) NULL,
        CancelledDate datetime2 NULL,
        CancelledBy bigint NULL,
        CancellationReason nvarchar(1000) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADServiceComplaint_IsActive DEFAULT (1),
        CreateDate datetime2 NOT NULL CONSTRAINT DF_TDADServiceComplaint_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2 NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADServiceComplaint_CompanyNo UNIQUE (CompanyID, ComplaintNo),
        CONSTRAINT CK_TDADServiceComplaint_Status CHECK (StatusCode IN (N'NEW',N'IN_PROGRESS',N'COMPLETED',N'CANCELLED'))
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceComplaint') AND name=N'IX_TDADServiceComplaint_CompanyStatusDate')
    CREATE INDEX IX_TDADServiceComplaint_CompanyStatusDate ON dbo.TDADServiceComplaint(CompanyID, StatusCode, RequestDate DESC, ComplaintID DESC);

IF OBJECT_ID(N'dbo.TDADServiceComplaintAttachment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADServiceComplaintAttachment
    (
        ComplaintAttachmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADServiceComplaintAttachment PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ComplaintID bigint NOT NULL,
        FileName nvarchar(255) NOT NULL,
        StoredPath nvarchar(500) NOT NULL,
        ContentType nvarchar(100) NOT NULL,
        FileSize bigint NOT NULL,
        ImageWidth int NULL,
        ImageHeight int NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADServiceComplaintAttachment_IsActive DEFAULT (1),
        CreateDate datetime2 NOT NULL CONSTRAINT DF_TDADServiceComplaintAttachment_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2 NULL,
        UpdateBy bigint NULL,
        CONSTRAINT FK_TDADServiceComplaintAttachment_Complaint FOREIGN KEY (ComplaintID) REFERENCES dbo.TDADServiceComplaint(ComplaintID)
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceComplaintAttachment') AND name=N'IX_TDADServiceComplaintAttachment_CompanyComplaint')
    CREATE INDEX IX_TDADServiceComplaintAttachment_CompanyComplaint ON dbo.TDADServiceComplaintAttachment(CompanyID, ComplaintID, IsActive);

COMMIT TRANSACTION;