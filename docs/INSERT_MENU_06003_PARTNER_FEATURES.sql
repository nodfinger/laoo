/* Partner Admin menu for enabling/disabling customer options. */
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @MenuGroupCode nvarchar(20);
SELECT @MenuGroupCode = MenuGroupCode
FROM dbo.TDADMainMenu
WHERE MenuCode = N'06001';

IF @MenuGroupCode IS NULL
    THROW 50020, N'ไม่พบเมนู 06001 สำหรับอ้างอิงกลุ่มเมนู Partner', 1;

IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'06003')
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuName = N'จัดการ Option',
        MenuGroupCode = @MenuGroupCode,
        RouteName = N'partnerCompanyFeatures',
        RoutePath = N'/partner/company-features',
        ScreenType = 2,
        FeatureCode = NULL,
        IconName = N'toggle_on_outlined',
        IsFavoriteAllowed = 1,
        IsActive = 1,
        IsVisible = 1
    WHERE MenuCode = N'06003';
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
        N'06003', N'จัดการ Option', @MenuGroupCode,
        N'partnerCompanyFeatures', N'/partner/company-features',
        2, NULL, N'toggle_on_outlined',
        ISNULL(MAX(SortOrder), 0) + 1,
        1, 1, 1
    FROM dbo.TDADMainMenu
    WHERE MenuGroupCode = @MenuGroupCode;
END;

COMMIT TRANSACTION;

SELECT MenuCode, MenuName, MenuGroupCode, RouteName, RoutePath, ScreenType
FROM dbo.TDADMainMenu
WHERE MenuCode = N'06003';
