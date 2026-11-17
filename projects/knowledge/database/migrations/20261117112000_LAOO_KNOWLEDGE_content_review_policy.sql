IF OBJECT_ID(N'dbo.TDKNContentReviewPolicy',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDKNContentReviewPolicy (
        CompanyID bigint NOT NULL,
        ContentType nvarchar(40) NOT NULL,
        RequireReview bit NOT NULL CONSTRAINT DF_TDKNContentReviewPolicy_Review DEFAULT (1),
        UpdateBy bigint NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_TDKNContentReviewPolicy_Update DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_TDKNContentReviewPolicy PRIMARY KEY (CompanyID,ContentType)
    );
END;
