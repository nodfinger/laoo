/*
  Add the SALES_MANAGEMENT menu group and its first customer menu.

  MenuGroupCode : 13
  MenuCode      : 13001
  AudienceType  : C (Customer)
  ScreenType    : 1 (CRUD)
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode = N'13')
BEGIN
    UPDATE dbo.TDADMenuGroup
    SET MenuGroupName = N'ระบบบริหารงานขาย',
        AudienceType = N'C',
        IsActive = CAST(1 AS bit),
        IsExpandedDefault = CAST(0 AS bit)
    WHERE MenuGroupCode = N'13';
END
ELSE
BEGIN
    INSERT dbo.TDADMenuGroup
    (
        MenuGroupCode,
        MenuGroupName,
        IconName,
        SortOrder,
        IsExpandedDefault,
        AudienceType,
        IsActive
    )
    SELECT
        N'13',
        N'ระบบบริหารงานขาย',
        N'groups_outlined',
        ISNULL(MAX(SortOrder), 0) + 1,
        CAST(0 AS bit),
        N'C',
        CAST(1 AS bit)
    FROM dbo.TDADMenuGroup;
END;

IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'13001')
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuName = N'บริหารงานขาย',
        MenuGroupCode = N'13',
        RouteName = N'salesManagement',
        RoutePath = N'/company/sales-management',
        FeatureCode = N'SALES_MANAGEMENT',
        IconName = N'point_of_sale_outlined',
        ScreenType = 1,
        IsActive = CAST(1 AS bit),
        IsVisible = CAST(1 AS bit)
    WHERE MenuCode = N'13001';
END
ELSE
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuCode,
        MenuName,
        MenuGroupCode,
        RouteName,
        RoutePath,
        ScreenType,
        FeatureCode,
        IconName,
        SortOrder,
        IsFavoriteAllowed,
        IsActive,
        IsVisible
    )
    VALUES
    (
        N'13001',
        N'บริหารงานขาย',
        N'13',
        N'salesManagement',
        N'/company/sales-management',
        1,
        N'SALES_MANAGEMENT',
        N'point_of_sale_outlined',
        1,
        CAST(1 AS bit),
        CAST(1 AS bit),
        CAST(1 AS bit)
    );
END;

COMMIT TRANSACTION;

SELECT
    G.MenuGroupCode,
    G.MenuGroupName,
    M.MenuCode,
    M.MenuName,
    M.FeatureCode,
    M.ScreenType,
    G.AudienceType
FROM dbo.TDADMenuGroup AS G
INNER JOIN dbo.TDADMainMenu AS M ON M.MenuGroupCode = G.MenuGroupCode
WHERE G.MenuGroupCode = N'13'
  AND M.MenuCode = N'13001';
