SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTCompanySetUp', N'U') IS NULL
    THROW 53711, N'Company setup table is missing.', 1;

-- Preserve the existing availability of chat for existing companies.
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatEnabled') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatEnabled bit NOT NULL
        CONSTRAINT DF_TDSTCompanySetUp_AiChatEnabled DEFAULT (1) WITH VALUES;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatName') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatName nvarchar(100) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatPronoun') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatPronoun nvarchar(50) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatGreetingMode') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatGreetingMode tinyint NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatMorningStart') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatMorningStart time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatMorningEnd') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatMorningEnd time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatMorningText') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatMorningText nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatLateMorningStart') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatLateMorningStart time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatLateMorningEnd') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatLateMorningEnd time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatLateMorningText') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatLateMorningText nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatAfternoonStart') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatAfternoonStart time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatAfternoonEnd') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatAfternoonEnd time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatAfternoonText') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatAfternoonText nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatEveningStart') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatEveningStart time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatEveningEnd') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatEveningEnd time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatEveningText') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatEveningText nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatShowUserImage') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatShowUserImage bit NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatShowAiImage') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatShowAiImage bit NULL;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiChatImagePath') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiChatImagePath nvarchar(1000) NULL;
