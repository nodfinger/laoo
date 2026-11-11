SET NOCOUNT ON;
SET XACT_ABORT ON;
IF COL_LENGTH(N'dbo.TDADMainMenu',N'AllowPrint') IS NULL
    THROW 54310, N'Main menu print flag is missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'66001' AND ScreenType=4 AND IsActive=1)
    THROW 54311, N'Travel claim menu is missing or has an unexpected screen type.', 1;
UPDATE dbo.TDADMainMenu SET AllowPrint=1 WHERE MenuCode=N'66001' AND AllowPrint=0;
