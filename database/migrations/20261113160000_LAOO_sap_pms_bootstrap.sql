SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @project bigint = (
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_MY' AND IsActive = 1
);

IF @project IS NULL
    THROW 54300, N'Active LAOO_MY project entitlement was not found.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.TDADMainMenu
    WHERE MenuCode = N'65002'
      AND MenuGroupCode = N'65'
      AND ScreenType = 3
      AND RouteName = N'mySystemSapPms'
      AND RoutePath = N'/company/my-system/sap-pms'
      AND FeatureCode = N'MY_SYSTEM'
      AND IsActive = 1
)
    THROW 54301, N'SAP-PMS menu contract differs from the registered Core contract.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.TDADPermission
    WHERE ProjectID = @project
      AND ScreenCode = N'65002'
      AND ActionCode = N'VIEW'
      AND IsActive = 1
)
    THROW 54302, N'SAP-PMS VIEW permission is missing from LAOO_MY.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.TDADProjectMenu
    WHERE ProjectID = @project AND MenuCode = N'65002'
)
BEGIN
    INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive)
    SELECT @project, MenuCode, MenuGroupCode, SortOrder, 0
    FROM dbo.TDADMainMenu
    WHERE MenuCode = N'65002';
END
ELSE
BEGIN
    UPDATE dbo.TDADProjectMenu
    SET MenuGroupCode = N'65', IsActive = 0, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @project AND MenuCode = N'65002';
END;
