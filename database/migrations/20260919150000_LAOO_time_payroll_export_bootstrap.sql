/* Core-owned Time payroll export menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @TimeProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1);
 IF @TimeProjectID IS NULL THROW 52950,N'Active LAOO_TIME project is required.',1;
 DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuGroupCode char(2),MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
 INSERT @Menus VALUES
 (N'28013',N'28',N'รูปแบบ Export Payroll',1,N'timePayrollExportProfiles',N'/company/time-payroll-export-profiles',N'TIME_PAYROLL_EXPORT_PROFILES',N'file_copy_outlined',130),
 (N'25003',N'25',N'สร้าง Export Payroll',4,N'timePayrollExport',N'/company/time-payroll-export',N'TIME_PAYROLL_EXPORT',N'upload_file_outlined',30),
 (N'25004',N'25',N'ประวัติ Export Payroll',3,N'timePayrollExportHistory',N'/company/time-payroll-export-history',N'TIME_PAYROLL_EXPORT_HISTORY',N'history_outlined',40);
 IF EXISTS(SELECT 1 FROM @Menus source INNER JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode WHERE target.MenuGroupCode<>source.MenuGroupCode OR target.ScreenType<>source.ScreenType OR ISNULL(target.RouteName,N'')<>source.RouteName OR ISNULL(target.RoutePath,N'')<>source.RoutePath) THROW 52951,N'Time payroll export MenuCode conflicts with an existing contract.',1;
 IF EXISTS(SELECT 1 FROM @Menus source INNER JOIN dbo.TDADMainMenu target ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath) AND target.MenuCode<>source.MenuCode) THROW 52952,N'Time payroll export route conflicts with an existing menu.',1;
 UPDATE target SET MenuGroupCode=source.MenuGroupCode,MenuName=source.MenuName,ScreenType=source.ScreenType,RouteName=source.RouteName,RoutePath=source.RoutePath,FeatureCode=source.FeatureCode,IconName=source.IconName,SortOrder=source.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu target INNER JOIN @Menus source ON source.MenuCode=target.MenuCode;
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) SELECT MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus source WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode);
 UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@TimeProjectID AND MenuGroupCode IN(N'25',N'28');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@TimeProjectID AND MenuGroupCode=N'25') INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@TimeProjectID,N'25',25,1,SYSUTCDATETIME());
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@TimeProjectID AND MenuGroupCode=N'28') INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@TimeProjectID,N'28',28,1,SYSUTCDATETIME()); /* Inactive until projects/time provides GoRoutes, API and UI. */
 UPDATE target SET MenuGroupCode=source.MenuGroupCode,SortOrder=source.SortOrder,IsActive=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu target INNER JOIN @Menus source ON source.MenuCode=target.MenuCode WHERE target.ProjectID=@TimeProjectID;
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @TimeProjectID,MenuCode,MenuGroupCode,SortOrder,0,SYSUTCDATETIME() FROM @Menus source WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu target WHERE target.ProjectID=@TimeProjectID AND target.MenuCode=source.MenuCode);
 UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode IN(N'28013',N'25003',N'25004') AND ProjectID<>@TimeProjectID AND IsActive=1;
 DECLARE @Permissions TABLE(ScreenCode nvarchar(50),ScreenNameTH nvarchar(200),ScreenNameEN nvarchar(200),ActionCode nvarchar(50),ActionNameTH nvarchar(200),ActionNameEN nvarchar(200),PRIMARY KEY(ScreenCode,ActionCode));
 INSERT @Permissions VALUES
 (N'28013',N'รูปแบบ Export Payroll',N'Payroll export profiles',N'VIEW',N'ดูข้อมูล',N'View'),(N'28013',N'รูปแบบ Export Payroll',N'Payroll export profiles',N'CREATE',N'เพิ่มข้อมูล',N'Create'),(N'28013',N'รูปแบบ Export Payroll',N'Payroll export profiles',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),(N'28013',N'รูปแบบ Export Payroll',N'Payroll export profiles',N'DELETE',N'ลบข้อมูล',N'Delete'),
 (N'25003',N'สร้าง Export Payroll',N'Generate payroll export',N'VIEW',N'ดูข้อมูล',N'View'),(N'25003',N'สร้าง Export Payroll',N'Generate payroll export',N'CREATE',N'เพิ่มข้อมูล',N'Create'),(N'25003',N'สร้าง Export Payroll',N'Generate payroll export',N'FINALIZE',N'ยืนยันสร้าง Export',N'Finalize'),
 (N'25004',N'ประวัติ Export Payroll',N'Payroll export history',N'VIEW',N'ดูข้อมูล',N'View'),(N'25004',N'ประวัติ Export Payroll',N'Payroll export history',N'DOWNLOAD',N'ดาวน์โหลด',N'Download');
 UPDATE target SET ScreenNameTH=source.ScreenNameTH,ScreenNameEN=source.ScreenNameEN,ActionNameTH=source.ActionNameTH,ActionNameEN=source.ActionNameEN,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission target INNER JOIN @Permissions source ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode WHERE target.ProjectID=@TimeProjectID;
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) SELECT @TimeProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,1,SYSUTCDATETIME() FROM @Permissions source WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission target WHERE target.ProjectID=@TimeProjectID AND target.ScreenCode=source.ScreenCode AND target.ActionCode=source.ActionCode);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO