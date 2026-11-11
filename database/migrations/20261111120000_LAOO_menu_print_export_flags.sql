SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADMainMenu',N'U') IS NULL
    THROW 54301, N'Main menu table is missing.', 1;
IF COL_LENGTH(N'dbo.TDADMainMenu',N'AllowPrint') IS NULL
    ALTER TABLE dbo.TDADMainMenu ADD AllowPrint bit NOT NULL
        CONSTRAINT DF_TDADMainMenu_AllowPrint DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.TDADMainMenu',N'AllowExport') IS NULL
    ALTER TABLE dbo.TDADMainMenu ADD AllowExport bit NOT NULL
        CONSTRAINT DF_TDADMainMenu_AllowExport DEFAULT (0) WITH VALUES;
