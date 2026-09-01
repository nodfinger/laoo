/*
  Company Pre-order menu.

  MenuGroupCode : 09 (ระบบขาย)
  MenuCode      : 09004
  MenuName      : ใบรับจองสินค้า
  ScreenType    : 4 (document header/detail)

  Company Admin access:
  The existing authorization layer grants Company Admin full menu access when
  TDADUser.IsCompanyAdmin = 1. No separate permission rows are inserted here.
  Other users continue to use the normal VIEW/CREATE/EDIT/DELETE rules.
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
    THROW 50026, N'ไม่พบกลุ่มเมนู 09 สำหรับ Customer/Company Admin', 1;

IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'09004')
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuName = N'ใบรับจองสินค้า',
        MenuGroupCode = @MenuGroupCode,
        RouteName = N'companyPreOrders',
        RoutePath = N'/company/pre-orders',
        ScreenType = 4,
        FeatureCode = NULL,
        IconName = N'shopping_cart_checkout_outlined',
        IsFavoriteAllowed = 1,
        IsActive = 1,
        IsVisible = 1
    WHERE MenuCode = N'09004';
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
        N'09004', N'ใบรับจองสินค้า', @MenuGroupCode,
        N'companyPreOrders', N'/company/pre-orders',
        4, NULL, N'shopping_cart_checkout_outlined',
        ISNULL(MAX(SortOrder), 0) + 1,
        CAST(1 AS bit), CAST(1 AS bit), CAST(1 AS bit)
    FROM dbo.TDADMainMenu
    WHERE MenuGroupCode = @MenuGroupCode;
END;

COMMIT TRANSACTION;

SELECT
    G.MenuGroupCode,
    G.MenuGroupName,
    M.MenuCode,
    M.MenuName,
    M.RouteName,
    M.RoutePath,
    M.ScreenType,
    M.FeatureCode,
    G.AudienceType
FROM dbo.TDADMenuGroup AS G
INNER JOIN dbo.TDADMainMenu AS M ON M.MenuGroupCode = G.MenuGroupCode
WHERE M.MenuCode = N'09004';
