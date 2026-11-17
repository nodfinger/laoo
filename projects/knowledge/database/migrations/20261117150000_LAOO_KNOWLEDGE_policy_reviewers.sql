IF OBJECT_ID(N'dbo.TDKNContentPolicyReviewer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDKNContentPolicyReviewer (
        CompanyID bigint NOT NULL,
        ContentType nvarchar(40) NOT NULL,
        ReviewerUserID bigint NOT NULL,
        CreateBy bigint NOT NULL,
        CreateDate datetime2 NOT NULL CONSTRAINT DF_TDKNContentPolicyReviewer_CreateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TDKNContentPolicyReviewer PRIMARY KEY (CompanyID, ContentType, ReviewerUserID)
    );
END;
