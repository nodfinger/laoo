/* Add LAOO-only menu in menu group 01. */
DECLARE @MenuGroupCode nvarchar(20);
SELECT @MenuGroupCode = MenuGroupCode
FROM dbo.TDADMainMenu
WHERE MenuCode = N'01001';

IF @MenuGroupCode IS NULL
    THROW 50002, 'ไม่พบเมนู 01001 สำหรับอ้างอิงกลุ่มเมนู 01', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'01005')
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuCode, MenuName, MenuGroupCode, RouteName, RoutePath,
        FeatureCode, IconName, ScreenType, SortOrder,
        IsFavoriteAllowed, IsActive, IsVisible
    )
    SELECT
        N'01005', N'กำหนดค่าส่วนกลาง', @MenuGroupCode,
        N'globalSettings', N'/support/global-settings',
        N'01005', N'tune_outlined', 1,
        ISNULL(MAX(SortOrder), 0) + 1,
        CAST(1 AS bit), CAST(1 AS bit), CAST(1 AS bit)
    FROM dbo.TDADMainMenu
    WHERE MenuGroupCode = @MenuGroupCode;
END;
ELSE
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuName = N'กำหนดค่าส่วนกลาง',
        RouteName = N'globalSettings',
        RoutePath = N'/support/global-settings',
        FeatureCode = N'01005',
        IconName = N'tune_outlined',
        ScreenType = 1,
        IsActive = 1,
        IsVisible = 1
    WHERE MenuCode = N'01005';
END;
