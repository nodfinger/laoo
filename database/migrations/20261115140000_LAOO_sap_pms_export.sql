IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'65002' AND ScreenType=3)
    THROW 51000, 'Menu 65002 must exist as ScreenType 3 before enabling export.', 1;

UPDATE dbo.TDADMainMenu SET AllowExport=1 WHERE MenuCode=N'65002' AND ScreenType=3 AND AllowExport=0;
