SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTCompanySetUp', N'U') IS NULL
    THROW 53711, N'Company setup table is missing.', 1;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatNightStart') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatNightStart time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatNightEnd') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatNightEnd time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatNightText') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatNightText nvarchar(200) NULL;
