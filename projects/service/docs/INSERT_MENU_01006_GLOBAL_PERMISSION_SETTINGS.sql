/* Add menu 01006: กำหนดค่าสิทธิ์ส่วนกลาง */
DECLARE @MenuGroupCode NVARCHAR(20);

SELECT @MenuGroupCode = MenuGroupCode
FROM dbo.TDADMainMenu
WHERE MenuCode = N'01001';

IF @MenuGroupCode IS NULL
    THROW 50003, 'ไม่พบเมนู 01001 สำหรับอ้างอิงกลุ่มเมนู 01', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADMainMenu
    WHERE MenuCode = N'01006'
)
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuCode, MenuName, MenuGroupCode, RouteName, RoutePath,
        FeatureCode, IconName, ScreenType, SortOrder,
        IsFavoriteAllowed, IsActive, IsVisible
    )
    SELECT
        N'01006', N'กำหนดค่าสิทธิ์ส่วนกลาง', @MenuGroupCode,
        N'globalPermissionSettings', N'/support/global-permission-settings',
        N'01006', N'policy_outlined', 2,
        ISNULL(MAX(SortOrder), 0) + 1,
        CAST(1 AS BIT), CAST(1 AS BIT), CAST(1 AS BIT)
    FROM dbo.TDADMainMenu
    WHERE MenuGroupCode = @MenuGroupCode;
END
ELSE
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuName = N'กำหนดค่าสิทธิ์ส่วนกลาง',
        MenuGroupCode = @MenuGroupCode,
        RouteName = N'globalPermissionSettings',
        RoutePath = N'/support/global-permission-settings',
        FeatureCode = N'01006',
        IconName = N'policy_outlined',
        ScreenType = 2,
        IsActive = 1,
        IsVisible = 1
    WHERE MenuCode = N'01006';
END;
