SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'05002' AND MenuName=N'รหัสพื้นฐาน')
    THROW 54060, N'Master data menu 05002 was not found.', 1;

UPDATE dbo.TDADMainMenu
SET AllowListDisplaySettings=1
WHERE MenuCode=N'05002' AND MenuName=N'รหัสพื้นฐาน';
