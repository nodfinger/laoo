SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @TrainingProjectID bigint =
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TRAINING' AND IsActive=1);
    IF @TrainingProjectID IS NULL THROW 52970,N'Active LAOO_TRAINING project is required.',1;
    IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'37006' AND
        (MenuGroupCode<>N'37' OR ScreenType<>3 OR ISNULL(RouteName,N'')<>N'myTraining' OR ISNULL(RoutePath,N'')<>N'/company/my-training'))
        THROW 52971,N'My training MenuCode conflicts with an existing contract.',1;
    IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE
        (RouteName=N'myTraining' OR RoutePath=N'/company/my-training') AND MenuCode<>N'37006')
        THROW 52972,N'My training route conflicts with an existing menu.',1;
    UPDATE dbo.TDADMainMenu
    SET MenuGroupCode=N'37',MenuName=N'การอบรมของฉัน',ScreenType=3,
        RouteName=N'myTraining',RoutePath=N'/company/my-training',
        FeatureCode=N'MY_TRAINING',IconName=N'school_outlined',SortOrder=60,
        IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,
        UpdateDate=SYSUTCDATETIME()
    WHERE MenuCode=N'37006';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'37006')
        INSERT dbo.TDADMainMenu
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
        VALUES
        (N'37006',N'37',N'การอบรมของฉัน',3,N'myTraining',N'/company/my-training',N'MY_TRAINING',N'school_outlined',60,1,1,1,SYSUTCDATETIME(),0);
    UPDATE dbo.TDADProjectMenu
    SET MenuGroupCode=N'37',SortOrder=60,IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@TrainingProjectID AND MenuCode=N'37006';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@TrainingProjectID AND MenuCode=N'37006')
        INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
        VALUES(@TrainingProjectID,N'37006',N'37',60,1,SYSUTCDATETIME());
    UPDATE dbo.TDADProjectMenu
    SET IsActive=0,UpdateDate=SYSUTCDATETIME()
    WHERE MenuCode=N'37006' AND ProjectID<>@TrainingProjectID AND IsActive=1;
    UPDATE dbo.TDADPermission
    SET ScreenNameTH=N'การอบรมของฉัน',ScreenNameEN=N'My training',
        ActionNameTH=N'ดูข้อมูล',ActionNameEN=N'View',IsActive=1,
        ModifiedDate=SYSUTCDATETIME()
    WHERE ProjectID=@TrainingProjectID AND ScreenCode=N'37006' AND ActionCode=N'VIEW';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@TrainingProjectID AND ScreenCode=N'37006' AND ActionCode=N'VIEW')
        INSERT dbo.TDADPermission
        (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
        VALUES(@TrainingProjectID,N'37006',N'การอบรมของฉัน',N'My training',N'VIEW',N'ดูข้อมูล',N'View',1,SYSUTCDATETIME());
    UPDATE dbo.TDADPermission
    SET IsActive=0,ModifiedDate=SYSUTCDATETIME()
    WHERE ProjectID=@TrainingProjectID AND ScreenCode=N'37006' AND ActionCode<>N'VIEW' AND IsActive=1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
