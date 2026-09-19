/* Core-owned Training test-template menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @TrainingProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TRAINING' AND IsActive=1);
 IF @TrainingProjectID IS NULL THROW 52940,N'Active LAOO_TRAINING project is required.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'37003' AND (MenuGroupCode<>N'37' OR ScreenType<>1 OR ISNULL(RouteName,N'')<>N'trainingTestTemplates' OR ISNULL(RoutePath,N'')<>N'/company/training-test-templates')) THROW 52941,N'Training test template MenuCode conflicts with an existing contract.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE (RouteName=N'trainingTestTemplates' OR RoutePath=N'/company/training-test-templates') AND MenuCode<>N'37003') THROW 52942,N'Training test template route conflicts with an existing menu.',1;
 UPDATE dbo.TDADMainMenu SET MenuGroupCode=N'37',MenuName=N'ชุดแบบทดสอบอบรม',ScreenType=1,RouteName=N'trainingTestTemplates',RoutePath=N'/company/training-test-templates',FeatureCode=N'TRAINING_TEST_TEMPLATES',IconName=N'quiz_outlined',SortOrder=30,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'37003';
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'37003') INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) VALUES(N'37003',N'37',N'ชุดแบบทดสอบอบรม',1,N'trainingTestTemplates',N'/company/training-test-templates',N'TRAINING_TEST_TEMPLATES',N'quiz_outlined',30,1,1,1,SYSUTCDATETIME(),0);
 /* Active because this PR supplies a non-CRUD Training package placeholder route. */
 UPDATE dbo.TDADProjectMenu SET MenuGroupCode=N'37',SortOrder=30,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@TrainingProjectID AND MenuCode=N'37003';
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@TrainingProjectID AND MenuCode=N'37003') INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@TrainingProjectID,N'37003',N'37',30,1,SYSUTCDATETIME());
 UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'37003' AND ProjectID<>@TrainingProjectID AND IsActive=1;
 DECLARE @Permissions TABLE(ActionCode nvarchar(50) PRIMARY KEY,ActionNameTH nvarchar(200),ActionNameEN nvarchar(200));
 INSERT @Permissions VALUES(N'VIEW',N'ดูข้อมูล',N'View'),(N'CREATE',N'เพิ่มข้อมูล',N'Create'),(N'EDIT',N'แก้ไขข้อมูล',N'Edit'),(N'DELETE',N'ลบข้อมูล',N'Delete');
 UPDATE target SET ScreenNameTH=N'ชุดแบบทดสอบอบรม',ScreenNameEN=N'Training test templates',ActionNameTH=source.ActionNameTH,ActionNameEN=source.ActionNameEN,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission target INNER JOIN @Permissions source ON source.ActionCode=target.ActionCode WHERE target.ProjectID=@TrainingProjectID AND target.ScreenCode=N'37003';
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) SELECT @TrainingProjectID,N'37003',N'ชุดแบบทดสอบอบรม',N'Training test templates',source.ActionCode,source.ActionNameTH,source.ActionNameEN,1,SYSUTCDATETIME() FROM @Permissions source WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission target WHERE target.ProjectID=@TrainingProjectID AND target.ScreenCode=N'37003' AND target.ActionCode=source.ActionCode);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO