SET NOCOUNT ON;

-- Finance menus remain registered for stable contracts, but must not appear
-- in Navigation until their API, Flutter flow and permission tests are ready.
UPDATE dbo.TDADMainMenu
SET IsVisible = 0
WHERE MenuCode IN (
    N'09009', N'09011', N'09012', N'09013', N'09014',
    N'09015', N'09016', N'09021', N'09022'
) AND IsVisible = 1;
