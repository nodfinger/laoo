SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SITE')
    THROW 63001, N'LAOO_SITE project already exists', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'63001' AND N'63008')
    THROW 63002, N'LAOO_SITE menu code conflict', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'63')
    THROW 63003, N'LAOO_SITE menu group conflict', 1;

INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
VALUES(N'LAOO_SITE',N'ระบบตรวจไซต์งานผู้รับเหมา',N'Contractor Site Management',
       N'Customer-facing site projects, independent of LAOO_PROJECT',1,SYSUTCDATETIME(),N'BUSINESS',250,N'engineering_outlined',0);
DECLARE @ProjectID bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
VALUES(N'C',N'63',N'ระบบตรวจไซต์งานผู้รับเหมา',N'engineering_outlined',630,0,1,SYSUTCDATETIME(),0,0);

DECLARE @Menus TABLE(Code char(5),Name nvarchar(150),ScreenType int,Route nvarchar(150),Icon nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'63001',N'ตั้งค่าระบบตรวจไซต์งาน',2,N'site-settings',N'settings_outlined',10),
(N'63002',N'โครงการไซต์และลูกค้า',1,N'site-projects',N'engineering_outlined',20),
(N'63003',N'บันทึกงานรายวัน',4,N'site-daily-reports',N'edit_note_outlined',30),
(N'63004',N'ตรวจและเผยแพร่',3,N'site-publications',N'fact_check_outlined',40),
(N'63005',N'ปัญหาหน้างาน',1,N'site-issues',N'report_problem_outlined',50),
(N'63006',N'ส่งมอบงาน',4,N'site-handovers',N'handshake_outlined',60),
(N'63007',N'พอร์ทัลลูกค้า',3,N'site-customer-portal',N'account_circle_outlined',70),
(N'63008',N'Dashboard และรายงาน',3,N'site-dashboard',N'analytics_outlined',80);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT Code,N'63',Name,ScreenType,Route,N'/company/'+Route,N'SITE_'+Code,Icon,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
VALUES(@ProjectID,N'63',1,1,SYSUTCDATETIME());
-- No unfinished screen is exposed in Navigation.
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ProjectID,Code,N'63',SortOrder,0,SYSUTCDATETIME() FROM @Menus;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,Code,Name,Route,N'VIEW',N'ดู',N'View',1,SYSUTCDATETIME() FROM @Menus;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,Code,Name,Route,A.ActionCode,A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM @Menus M CROSS JOIN (VALUES(N'CREATE'),(N'EDIT'),(N'DELETE')) A(ActionCode)
WHERE M.ScreenType=1;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,Code,Name,Route,N'EDIT',N'แก้ไข',N'Edit',1,SYSUTCDATETIME()
FROM @Menus WHERE ScreenType=2;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,Code,Name,Route,A.ActionCode,A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM @Menus M CROSS JOIN (VALUES(N'CREATE'),(N'EDIT'),(N'CANCEL')) A(ActionCode)
WHERE M.ScreenType=4;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,Code,Name,Route,A.ActionCode,A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM @Menus M CROSS JOIN (VALUES(N'REVIEW'),(N'PUBLISH'),(N'RETURN')) A(ActionCode)
WHERE M.Code=N'63004';
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,Code,Name,Route,A.ActionCode,A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM @Menus M CROSS JOIN (VALUES(N'SUBMIT'),(N'ACCEPT'),(N'RETURN')) A(ActionCode)
WHERE M.Code=N'63006';
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive)
VALUES(@ProjectID,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
SELECT P.PackageID,N'SITE_'+M.Code,1
FROM dbo.TDADProjectPackage P CROSS JOIN @Menus M WHERE P.ProjectID=@ProjectID;
GO
