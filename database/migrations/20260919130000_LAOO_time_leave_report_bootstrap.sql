/* Core-owned Time leave report menu contract. The Time package activates it with its real GoRoute. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @TimeProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1);
 IF @TimeProjectID IS NULL THROW 52920,N'Active LAOO_TIME project is required.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'28012' AND (MenuGroupCode<>N'28' OR ScreenType<>3 OR ISNULL(RouteName,N'')<>N'timeLeaveReport' OR ISNULL(RoutePath,N'')<>N'/company/time-leave-report')) THROW 52921,N'Time leave report MenuCode conflicts with an existing contract.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE (RouteName=N'timeLeaveReport' OR RoutePath=N'/company/time-leave-report') AND MenuCode<>N'28012') THROW 52922,N'Time leave report route conflicts with an existing menu.',1;
 UPDATE dbo.TDADMainMenu SET MenuGroupCode=N'28',MenuName=N'รายงานสิทธิ์และการลา',ScreenType=3,RouteName=N'timeLeaveReport',RoutePath=N'/company/time-leave-report',FeatureCode=N'TIME_LEAVE_REPORT',IconName=N'assessment_outlined',SortOrder=120,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'28012';
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'28012') INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) VALUES(N'28012',N'28',N'รายงานสิทธิ์และการลา',3,N'timeLeaveReport',N'/company/time-leave-report',N'TIME_LEAVE_REPORT',N'assessment_outlined',120,1,1,1,SYSUTCDATETIME(),0);
 /* Kept inactive until projects/time supplies the real GoRoute and report API. */
 UPDATE dbo.TDADProjectMenu SET MenuGroupCode=N'28',SortOrder=120,IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@TimeProjectID AND MenuCode=N'28012';
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@TimeProjectID AND MenuCode=N'28012') INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@TimeProjectID,N'28012',N'28',120,0,SYSUTCDATETIME());
 UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'28012' AND ProjectID<>@TimeProjectID AND IsActive=1;
 UPDATE dbo.TDADPermission SET ScreenNameTH=N'รายงานสิทธิ์และการลา',ScreenNameEN=N'Time leave report',ActionNameTH=N'ดูข้อมูล',ActionNameEN=N'View',IsActive=1,ModifiedDate=SYSUTCDATETIME() WHERE ProjectID=@TimeProjectID AND ScreenCode=N'28012' AND ActionCode=N'VIEW';
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@TimeProjectID AND ScreenCode=N'28012' AND ActionCode=N'VIEW') INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) VALUES(@TimeProjectID,N'28012',N'รายงานสิทธิ์และการลา',N'Time leave report',N'VIEW',N'ดูข้อมูล',N'View',1,SYSUTCDATETIME());
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
