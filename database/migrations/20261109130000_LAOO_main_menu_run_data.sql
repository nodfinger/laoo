SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADMainMenu', N'U') IS NULL
    THROW 53910, N'Main menu table is unavailable.', 1;
IF COL_LENGTH(N'dbo.TDADMainMenu', N'RunData') IS NOT NULL
    THROW 53911, N'RunData already exists; review before applying.', 1;
ALTER TABLE dbo.TDADMainMenu ADD RunData bit NOT NULL
    CONSTRAINT DF_TDADMainMenu_RunData DEFAULT (0);
GO
UPDATE dbo.TDADMainMenu SET RunData=1 WHERE ScreenType=1;
