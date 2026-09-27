-- Core metadata activation for the completed Visitor exceptions screen (MenuCode 34003).
-- Keeps existing menu identity and route; adds only the required VIEW permission definition.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @VisitorProjectID bigint =
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR');

    IF @VisitorProjectID IS NULL
        THROW 53403, N'LAOO_VISITOR project was not found.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADMainMenu
        WHERE MenuCode=N'34003'
          AND MenuName=N'รายการผิดปกติ'
          AND ScreenType=3
          AND RouteName=N'visitorExceptions'
          AND RoutePath=N'/visitor/exceptions'
    )
        THROW 53404, N'MenuCode 34003 does not match the approved Visitor exceptions contract.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADProjectMenu
        WHERE ProjectID=@VisitorProjectID
          AND MenuCode=N'34003'
    )
        THROW 53405, N'Visitor project menu 34003 was not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'34')
        THROW 53406, N'Visitor menu group 34 was not found.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenuGroup
        WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'34'
    )
        THROW 53407, N'Visitor project menu group 34 was not found.', 1;

    -- Navigation requires both the shared and project-scoped parent group to be active.
    UPDATE dbo.TDADMenuGroup
    SET IsActive=1, UpdateDate=SYSUTCDATETIME()
    WHERE MenuGroupCode=N'34' AND IsActive=0;

    UPDATE dbo.TDADProjectMenuGroup
    SET IsActive=1, UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'34' AND IsActive=0;

    UPDATE dbo.TDADMainMenu
    SET IsActive=1, IsVisible=1, UpdateDate=SYSUTCDATETIME()
    WHERE MenuCode=N'34003' AND (IsActive=0 OR IsVisible=0);

    UPDATE dbo.TDADProjectMenu
    SET IsActive=1, UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@VisitorProjectID AND MenuCode=N'34003' AND IsActive=0;

    -- Show-only menu: retain VIEW and deactivate any obsolete action definition.
    UPDATE dbo.TDADPermission
    SET ScreenNameTH=N'รายการผิดปกติ',
        ScreenNameEN=N'Visitor Exceptions',
        ActionNameTH=N'ดูข้อมูล',
        ActionNameEN=N'View',
        IsActive=1,
        ModifiedDate=SYSUTCDATETIME()
    WHERE ProjectID=@VisitorProjectID
      AND ScreenCode=N'34003'
      AND ActionCode=N'VIEW';

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission
        WHERE ProjectID=@VisitorProjectID
          AND ScreenCode=N'34003'
          AND ActionCode=N'VIEW'
    )
        INSERT dbo.TDADPermission
            (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
        VALUES
            (@VisitorProjectID,N'34003',N'รายการผิดปกติ',N'Visitor Exceptions',N'VIEW',N'ดูข้อมูล',N'View',1,SYSUTCDATETIME());

    UPDATE dbo.TDADPermission
    SET IsActive=0, ModifiedDate=SYSUTCDATETIME()
    WHERE ProjectID=@VisitorProjectID
      AND ScreenCode=N'34003'
      AND ActionCode<>N'VIEW'
      AND IsActive=1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT m.MenuCode,m.MenuName,m.ScreenType,m.RouteName,m.RoutePath,m.IsActive,m.IsVisible,
       pm.IsActive AS ProjectMenuIsActive
FROM dbo.TDADMainMenu m
JOIN dbo.TDADProjectMenu pm ON pm.MenuCode=m.MenuCode
WHERE pm.ProjectID=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR')
  AND m.MenuCode=N'34003';

SELECT ScreenCode,ActionCode,IsActive
FROM dbo.TDADPermission
WHERE ProjectID=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR')
  AND ScreenCode=N'34003'
ORDER BY ActionCode;