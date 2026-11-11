IF OBJECT_ID(N'dbo.TDSTCompanyLogo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTCompanyLogo (
        CompanyID bigint NOT NULL PRIMARY KEY,
        ContentType nvarchar(50) NOT NULL,
        ImageData varbinary(max) NOT NULL,
        UpdatedBy bigint NULL,
        UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END;
