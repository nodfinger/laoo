SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PET') THROW 62001,N'Pet project already exists',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'62001' AND N'62010') THROW 62002,N'Pet menu code conflict',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'62') THROW 62003,N'Pet menu group conflict',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
VALUES(N'LAOO_PET',N'ระบบจัดการบริการสัตว์เลี้ยง',N'Pet Service Management',N'Pet hotel, grooming, day care and transport',1,SYSUTCDATETIME(),N'BUSINESS',240,N'pets_outlined',0);
DECLARE @P bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
VALUES(N'C',N'62',N'ระบบจัดการบริการสัตว์เลี้ยง',N'pets_outlined',620,0,1,SYSUTCDATETIME(),0,0);
DECLARE @M TABLE(Code char(5),Name nvarchar(150),ST int,Route nvarchar(150),Icon nvarchar(100),Sort int);
INSERT @M VALUES
(N'62001',N'ตั้งค่าระบบสัตว์เลี้ยง',2,N'pet-settings',N'settings_outlined',10),
(N'62002',N'ประเภทบริการ',1,N'pet-services',N'category_outlined',20),
(N'62003',N'ห้องและกรง',1,N'pet-rooms',N'grid_view_outlined',30),
(N'62004',N'โปรไฟล์สัตว์เลี้ยง',1,N'pet-profiles',N'pets_outlined',40),
(N'62005',N'แพ็กเกจและสมาชิก',1,N'pet-packages',N'card_membership_outlined',50),
(N'62006',N'นัดหมาย',4,N'pet-appointments',N'calendar_month_outlined',60),
(N'62007',N'เช็กอินและงานบริการ',4,N'pet-service-work',N'task_alt_outlined',70),
(N'62008',N'ประวัติบริการ',3,N'pet-history',N'history_outlined',80),
(N'62009',N'พอร์ทัลเจ้าของสัตว์',3,N'pet-owner-portal',N'account_circle_outlined',90),
(N'62010',N'Dashboard และรายงาน',3,N'pet-dashboard',N'analytics_outlined',100);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT Code,N'62',Name,ST,Route,N'/company/'+Route,N'PET_'+Code,Icon,Sort,1,1,1,SYSUTCDATETIME(),0 FROM @M;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@P,N'62',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @P,Code,N'62',Sort,1,SYSUTCDATETIME() FROM @M;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @P,Code,Name,Route,N'VIEW',N'ดู',N'View',1,SYSUTCDATETIME() FROM @M;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @P,Code,Name,Route,N'EDIT',N'แก้ไข',N'Edit',1,SYSUTCDATETIME() FROM @M WHERE ST=2;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @P,Code,Name,Route,A.Act,A.Act,A.Act,1,SYSUTCDATETIME() FROM @M CROSS JOIN (VALUES(N'CREATE'),(N'EDIT'),(N'DELETE')) A(Act) WHERE ST=1;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @P,Code,Name,Route,A.Act,A.Act,A.Act,1,SYSUTCDATETIME() FROM @M CROSS JOIN (VALUES(N'CREATE'),(N'EDIT'),(N'CANCEL'),(N'CHECKIN'),(N'COMPLETE')) A(Act) WHERE ST=4;
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive) VALUES(@P,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
SELECT X.PackageID,N'PET_'+M.Code,1 FROM dbo.TDADProjectPackage X CROSS JOIN @M M WHERE X.ProjectID=@P;
GO
