SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatRetentionDays') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatRetentionDays int NOT NULL
        CONSTRAINT DF_TDSTCompanySetUp_AiChatRetentionDays DEFAULT (90) WITH VALUES;

IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDSTCompanySetUp') AND name=N'CK_TDSTCompanySetUp_AiChatRetentionDays')
    EXEC(N'ALTER TABLE dbo.TDSTCompanySetUp ADD CONSTRAINT CK_TDSTCompanySetUp_AiChatRetentionDays CHECK (AiChatRetentionDays BETWEEN 1 AND 3650)');

IF OBJECT_ID(N'dbo.TDADAiChatReview', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADAiChatReview
    (
        ReviewID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADAiChatReview PRIMARY KEY,
        CompanyID bigint NOT NULL,
        UserID bigint NOT NULL,
        MessageKey uniqueidentifier NOT NULL,
        MessageText nvarchar(1000) NOT NULL,
        DepartmentID bigint NULL,
        DepartmentName nvarchar(200) NULL,
        BranchID bigint NULL,
        BranchName nvarchar(200) NULL,
        DetectedCapability nvarchar(100) NULL,
        SelectedCapability nvarchar(100) NULL,
        ReviewText nvarchar(1000) NULL,
        StatusCode varchar(25) NOT NULL CONSTRAINT DF_TDADAiChatReview_Status DEFAULT ('PENDING'),
        TestedText nvarchar(1000) NULL,
        TestedCapability nvarchar(100) NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_TDADAiChatReview_Created DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_TDADAiChatReview_Updated DEFAULT SYSUTCDATETIME(),
        UpdatedBy bigint NULL,
        CONSTRAINT UQ_TDADAiChatReview_Message UNIQUE (CompanyID,UserID,MessageKey),
        CONSTRAINT CK_TDADAiChatReview_Status CHECK (StatusCode IN ('PENDING','PREPARING','TESTING','AWAITING_APPROVAL','ACTIVE','REJECTED'))
    );
    CREATE INDEX IX_TDADAiChatReview_CompanyCreated ON dbo.TDADAiChatReview(CompanyID,CreatedAt);
END;
