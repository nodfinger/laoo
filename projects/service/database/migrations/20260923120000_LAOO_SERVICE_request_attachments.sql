IF OBJECT_ID(N'dbo.TDADServiceRequestAttachment',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADServiceRequestAttachment
    (
        AttachmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADServiceRequestAttachment PRIMARY KEY,
        CompanyID bigint NOT NULL,
        RequestID bigint NOT NULL,
        FileName nvarchar(255) NOT NULL,
        StoredPath nvarchar(500) NOT NULL,
        ContentType nvarchar(100) NOT NULL,
        FileSize bigint NOT NULL,
        ImageWidth int NULL,
        ImageHeight int NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADServiceRequestAttachment_Active DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADServiceRequestAttachment_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDADServiceRequestAttachment_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDADServiceRequest(RequestID),
        CONSTRAINT CK_TDADServiceRequestAttachment_Size CHECK(FileSize > 0 AND FileSize <= 1048576)
    );
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceRequestAttachment') AND name=N'IX_TDADServiceRequestAttachment_Request')
    CREATE INDEX IX_TDADServiceRequestAttachment_Request ON dbo.TDADServiceRequestAttachment(CompanyID,RequestID,IsActive,CreateDate,AttachmentID);
