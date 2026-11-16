IF OBJECT_ID(N'dbo.TDSTBusinessCardDraft', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTBusinessCardDraft (
        DraftID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSTBusinessCardDraft PRIMARY KEY,
        CompanyID bigint NOT NULL,
        SubmittedBy bigint NOT NULL,
        Status varchar(12) NOT NULL CONSTRAINT DF_BusinessCardDraft_Status DEFAULT ('DRAFT'),
        Payload nvarchar(max) NOT NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_BusinessCardDraft_CreatedAt DEFAULT SYSUTCDATETIME(),
        SentAt datetime2 NULL,
        ReviewedAt datetime2 NULL,
        ReviewedBy bigint NULL,
        ContactID bigint NULL,
        CustomerID bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_BusinessCardDraft_Status CHECK (Status IN ('DRAFT','PENDING','APPROVED','DELETED')),
        CONSTRAINT CK_BusinessCardDraft_Payload CHECK (ISJSON(Payload) = 1)
    );
    CREATE INDEX IX_BusinessCardDraft_CompanyStatus ON dbo.TDSTBusinessCardDraft (CompanyID, Status, DraftID DESC) INCLUDE (SubmittedBy);
END;

IF OBJECT_ID(N'dbo.TDSTBusinessCardDraftImage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTBusinessCardDraftImage (
        DraftImageID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSTBusinessCardDraftImage PRIMARY KEY,
        DraftID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        OriginalName nvarchar(255) NOT NULL,
        ImageData varbinary(max) NOT NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_BusinessCardDraftImage_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_BusinessCardDraftImage_Draft FOREIGN KEY (DraftID) REFERENCES dbo.TDSTBusinessCardDraft(DraftID)
    );
    CREATE INDEX IX_BusinessCardDraftImage_Draft ON dbo.TDSTBusinessCardDraftImage (CompanyID, DraftID);
END;
