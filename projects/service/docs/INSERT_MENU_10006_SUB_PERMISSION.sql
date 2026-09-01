/*
  Add customer-only menu after MenuCode 10004 (สิทธิ์เมนู).
  Run this script once against DBTDLaoo.
  MenuCode 10005 is already used, therefore the next available code is 10006.
*/
DECLARE @MenuGroupCode nvarchar(20);
SELECT @MenuGroupCode = MenuGroupCode
FROM dbo.TDADMainMenu
WHERE MenuCode = N'10004';

IF @MenuGroupCode IS NULL
    THROW 50001, 'ไม่พบเมนู 10004 สำหรับอ้างอิงกลุ่มเมนู', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'10006')
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuCode, MenuName, MenuGroupCode, RouteName, RoutePath, ScreenType,
        FeatureCode, IconName, SortOrder, IsFavoriteAllowed, IsActive, IsVisible
    )
    SELECT
        N'10006', N'สิทธิ์ระดับย่อย', @MenuGroupCode,
        N'companySubPermissions', N'/company/sub-permissions', 2,
        NULL, N'device_hub_outlined',
        ISNULL(MAX(SortOrder), 0) + 1,
        CAST(1 AS bit), CAST(1 AS bit), CAST(1 AS bit)
    FROM dbo.TDADMainMenu
    WHERE MenuGroupCode = @MenuGroupCode;
END;
ELSE
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuName = N'สิทธิ์ระดับย่อย',
        RouteName = N'companySubPermissions',
        RoutePath = N'/company/sub-permissions',
        IconName = N'device_hub_outlined',
        ScreenType = 2,
        IsActive = 1,
        IsVisible = 1
    WHERE MenuCode = N'10006';
END;
