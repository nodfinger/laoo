/* Core-owned navigation and permission baseline for Training results. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @TrainingProjectID bigint =
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TRAINING' AND IsActive=1);
    IF @TrainingProjectID IS NULL THROW 52960,N'Active LAOO_TRAINING project is required.',1;

    IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'37005' AND (MenuGroupCode<>N'37' OR ScreenType<>3 OR ISNULL(RouteName,N'')<>N'trainingResults' OR ISNULL(RoutePath,N'')<>N'/company/training-results'))
        THROW 52961,N'Training results MenuCode conflicts with an existing contract.',1;
    IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE (RouteName=N'trainingResults' OR RoutePath=N'/company/training-results') AND MenuCode<>N'37005')
        THROW 52962,N'Training results route conflicts with an existing menu.',1;

    UPDATE dbo.TDADMainMenu SET MenuGroupCode=N'37',MenuName=N'ผลการอบรม',ScreenType=3,RouteName=N'trainingResults',RoutePath=N'/company/training-results',FeatureCode=N'TRAINING_RESULTS',IconName=N'assessment_outlined',SortOrder=50,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'37005';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'37005')
        INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
        VALUES(N'37005',N'37',N'ผลการอบรม',3,N'trainingResults',N'/company/training-results',N'TRAINING_RESULTS',N'assessment_outlined',50,1,1,1,SYSUTCDATETIME(),0);

    UPDATE dbo.TDADProjectMenu SET MenuGroupCode=N'37',SortOrder=50,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@TrainingProjectID AND MenuCode=N'37005';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@TrainingProjectID AND MenuCode=N'37005')
        INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@TrainingProjectID,N'37005',N'37',50,1,SYSUTCDATETIME());
    UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'37005' AND ProjectID<>@TrainingProjectID AND IsActive=1;

    UPDATE dbo.TDADPermission SET ScreenNameTH=N'ผลการอบรม',ScreenNameEN=N'Training results',ActionNameTH=N'ดูข้อมูล',ActionNameEN=N'View',IsActive=1,ModifiedDate=SYSUTCDATETIME() WHERE ProjectID=@TrainingProjectID AND ScreenCode=N'37005' AND ActionCode=N'VIEW';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@TrainingProjectID AND ScreenCode=N'37005' AND ActionCode=N'VIEW')
        INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) VALUES(@TrainingProjectID,N'37005',N'ผลการอบรม',N'Training results',N'VIEW',N'ดูข้อมูล',N'View',1,SYSUTCDATETIME());
    UPDATE dbo.TDADPermission SET IsActive=0,ModifiedDate=SYSUTCDATETIME() WHERE ProjectID=@TrainingProjectID AND ScreenCode=N'37005' AND ActionCode<>N'VIEW' AND IsActive=1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
