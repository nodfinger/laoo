SET NOCOUNT ON;

IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AddLogRun') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AddLogRun bit NOT NULL
        CONSTRAINT DF_TDSTCompanySetUp_AddLogRun DEFAULT (0) WITH VALUES;

IF OBJECT_ID(N'dbo.TDADCompanyRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADCompanyRunLog
    (
        RunLogID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADCompanyRunLog PRIMARY KEY,
        CompanyID bigint NOT NULL,
        CompanyName nvarchar(255) NOT NULL,
        IPAddress nvarchar(45) NULL,
        RunAt datetime2(3) NOT NULL,
        ChangeDescription nvarchar(max) NOT NULL,
        StatusAccept tinyint NOT NULL CONSTRAINT DF_TDADCompanyRunLog_StatusAccept DEFAULT (0)
    );
    CREATE INDEX IX_TDADCompanyRunLog_Company_RunAt
        ON dbo.TDADCompanyRunLog (CompanyID, RunAt DESC);
END;
