SET XACT_ABORT ON;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
    IF @ProjectID IS NULL THROW 54120, N'Active LAOO project is required.', 1;
    IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'01007' AND (MenuGroupCode<>N'01' OR ScreenType<>2 OR ISNULL(RouteName,N'')<>N'laooMenuManagement' OR ISNULL(RoutePath,N'')<>N'/support/menu-management'))
       THROW 54121, N'MenuCode 01007 conflicts with an existing route contract.', 1;
    IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode<>N'01007' AND (RouteName=N'laooMenuManagement' OR RoutePath=N'/support/menu-management'))
       THROW 54122, N'Menu management route conflicts with an existing menu.', 1;

    UPDATE dbo.TDADMainMenu SET MenuGroupCode=N'01',MenuName=N'จัดการเมนูระบบ',ScreenType=2,RouteName=N'laooMenuManagement',RoutePath=N'/support/menu-management',FeatureCode=N'LAOO_MENU_MANAGEMENT',IconName=N'format_list_numbered',SortOrder=43,IsVisible=1,IsFavoriteAllowed=0,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'01007';
    IF @@ROWCOUNT=0 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    VALUES(N'01007',N'01',N'จัดการเมนูระบบ',2,N'laooMenuManagement',N'/support/menu-management',N'LAOO_MENU_MANAGEMENT',N'format_list_numbered',43,1,0,1,SYSUTCDATETIME(),0);

    UPDATE dbo.TDADProjectMenu SET MenuGroupCode=N'01',SortOrder=43,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode=N'01007';
    IF @@ROWCOUNT=0 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,N'01007',N'01',43,1,SYSUTCDATETIME());

    DECLARE @Actions TABLE(ActionCode nvarchar(50) NOT NULL PRIMARY KEY);
    INSERT @Actions VALUES(N'VIEW'),(N'EDIT');
    UPDATE permission SET ScreenNameTH=N'จัดการเมนูระบบ',ScreenNameEN=N'LAOO_MENU_MANAGEMENT',ActionNameTH=actions.ActionCode,ActionNameEN=actions.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME()
    FROM dbo.TDADPermission permission JOIN @Actions actions ON actions.ActionCode=permission.ActionCode WHERE permission.ProjectID=@ProjectID AND permission.ScreenCode=N'01007';
    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @ProjectID,N'01007',N'จัดการเมนูระบบ',N'LAOO_MENU_MANAGEMENT',ActionCode,ActionCode,ActionCode,1,SYSUTCDATETIME() FROM @Actions actions
    WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission permission WHERE permission.ProjectID=@ProjectID AND permission.ScreenCode=N'01007' AND permission.ActionCode=actions.ActionCode);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;