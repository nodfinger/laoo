/*
  Customer-only quotation menu.

  MenuCode   : 09003
  MenuName   : ใบเสนอราคา
  ScreenType : 1
  Option     : not required; normal menu permission rules apply
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @MenuGroupCode nvarchar(20) = N'09';

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADMenuGroup
    WHERE MenuGroupCode = @MenuGroupCode
      AND UPPER(LTRIM(RTRIM(AudienceType))) IN (N'C', N'A')
)
    THROW 50025, N'ไม่พบกลุ่มเมนู 09 สำหรับ Customer', 1;

IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'09003')
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuName = N'ใบเสนอราคา',
        MenuGroupCode = @MenuGroupCode,
        RouteName = N'companyQuotations',
        RoutePath = N'/company/quotations',
        ScreenType = 1,
        FeatureCode = NULL,
        IconName = N'request_quote_outlined',
        IsFavoriteAllowed = 1,
        IsActive = 1,
        IsVisible = 1
    WHERE MenuCode = N'09003';
END
ELSE
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuCode, MenuName, MenuGroupCode, RouteName, RoutePath,
        ScreenType, FeatureCode, IconName, SortOrder,
        IsFavoriteAllowed, IsActive, IsVisible
    )
    SELECT
        N'09003', N'ใบเสนอราคา', @MenuGroupCode,
        N'companyQuotations', N'/company/quotations',
        1, NULL, N'request_quote_outlined',
        ISNULL(MAX(SortOrder), 0) + 1,
        1, 1, 1
    FROM dbo.TDADMainMenu
    WHERE MenuGroupCode = @MenuGroupCode;
END;

COMMIT TRANSACTION;

SELECT M.MenuCode, M.MenuName, M.MenuGroupCode, G.AudienceType,
       M.RouteName, M.RoutePath, M.ScreenType, M.FeatureCode
FROM dbo.TDADMainMenu M
INNER JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode = M.MenuGroupCode
WHERE M.MenuCode = N'09003';
