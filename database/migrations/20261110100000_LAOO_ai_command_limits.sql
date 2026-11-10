SET XACT_ABORT ON;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiFrequentCommandLimit') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiFrequentCommandLimit int NOT NULL CONSTRAINT DF_Company_AiFrequentCommandLimit DEFAULT (10) WITH VALUES;
IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'AiRecentCommandLimit') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD AiRecentCommandLimit int NOT NULL CONSTRAINT DF_Company_AiRecentCommandLimit DEFAULT (10) WITH VALUES;
IF COL_LENGTH(N'dbo.TDADUserProfile', N'AiFrequentCommandLimit') IS NULL
    ALTER TABLE dbo.TDADUserProfile ADD AiFrequentCommandLimit int NOT NULL CONSTRAINT DF_Profile_AiFrequentCommandLimit DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.TDADUserProfile', N'AiRecentCommandLimit') IS NULL
    ALTER TABLE dbo.TDADUserProfile ADD AiRecentCommandLimit int NOT NULL CONSTRAINT DF_Profile_AiRecentCommandLimit DEFAULT (0) WITH VALUES;
