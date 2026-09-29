-- Activate approved Survey preview menus without enabling business actions.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint =
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SURVEY' AND IsActive=1);
    IF @ProjectID IS NULL
        THROW 54007, N'Active LAOO_SURVEY project was not found.', 1;

    IF (SELECT COUNT(*) FROM dbo.TDADMainMenu
        WHERE MenuCode BETWEEN N'40001' AND N'40006' AND IsActive=1 AND IsVisible=1) <> 6
        THROW 54008, N'Existing Survey menus are missing or inactive.', 1;

    IF (SELECT COUNT(*) FROM dbo.TDADProjectMenu
        WHERE ProjectID=@ProjectID AND MenuCode BETWEEN N'40001' AND N'40006') <> 6
        THROW 54009, N'Existing Survey project menu mappings are incomplete.', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.TDADMainMenu
        WHERE MenuCode=N'40007'
          AND (MenuName<>N'แบบสอบถามของฉัน' OR ScreenType<>3
               OR RouteName<>N'mySurveys' OR RoutePath<>N'/company/my-surveys')
    )
        THROW 54010, N'Survey MenuCode 40007 conflicts with the approved contract.', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.TDADMainMenu
        WHERE MenuCode<>N'40007'
          AND (RouteName=N'mySurveys' OR RoutePath=N'/company/my-surveys')
    )
        THROW 54011, N'Survey 40007 route name or path is already in use.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'40')
        THROW 54012, N'Survey menu group 40 was not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenuGroup
                   WHERE ProjectID=@ProjectID AND MenuGroupCode=N'40')
        THROW 54013, N'Survey project menu group 40 was not found.', 1;

    INSERT dbo.TDADMainMenu
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,
         FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,
         IsActive,CreateDate,ShowPermissionPoint)
    SELECT N'40007',N'40',N'แบบสอบถามของฉัน',3,N'mySurveys',N'/company/my-surveys',
           N'SURVEY_MY',N'assignment_outlined',70,1,1,1,SYSUTCDATETIME(),0
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'40007');

    UPDATE dbo.TDADMainMenu
    SET IsActive=1,IsVisible=1,UpdateDate=SYSUTCDATETIME()
    WHERE MenuCode=N'40007' AND (IsActive=0 OR IsVisible=0);

    UPDATE dbo.TDADMenuGroup
    SET IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE MenuGroupCode=N'40' AND IsActive=0;

    UPDATE dbo.TDADProjectMenuGroup
    SET IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND MenuGroupCode=N'40' AND IsActive=0;

    UPDATE dbo.TDADProjectMenu
    SET IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID
      AND MenuCode BETWEEN N'40001' AND N'40006'
      AND IsActive=0;

    INSERT dbo.TDADProjectMenu
        (ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @ProjectID,N'40007',N'40',70,1,SYSUTCDATETIME()
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenu
                      WHERE ProjectID=@ProjectID AND MenuCode=N'40007');

    UPDATE dbo.TDADProjectMenu
    SET IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND MenuCode=N'40007' AND IsActive=0;

    IF EXISTS (SELECT 1 FROM dbo.TDADPermission
               WHERE ProjectID=@ProjectID AND ScreenCode=N'40007'
                 AND ActionCode<>N'VIEW' AND IsActive=1)
        THROW 54014, N'Survey 40007 preview permits VIEW only.', 1;

    INSERT dbo.TDADPermission
        (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,
         ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @ProjectID,N'40007',N'แบบสอบถามของฉัน',N'My Surveys',N'VIEW',
           N'ดูข้อมูล',N'View',1,SYSUTCDATETIME()
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADPermission
                      WHERE ProjectID=@ProjectID AND ScreenCode=N'40007'
                        AND ActionCode=N'VIEW');

    UPDATE dbo.TDADPermission
    SET ScreenNameTH=N'แบบสอบถามของฉัน',ScreenNameEN=N'My Surveys',
        ActionNameTH=N'ดูข้อมูล',ActionNameEN=N'View',
        IsActive=1,ModifiedDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND ScreenCode=N'40007'
      AND ActionCode=N'VIEW' AND IsActive=0;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
