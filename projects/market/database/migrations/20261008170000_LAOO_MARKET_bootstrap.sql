SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Run only through tools/scripts/run-migrations.ps1 after approval.
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MARKET')
 THROW 59001,N'LAOO_MARKET already exists.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'59001' AND N'59011')
 THROW 59002,N'Market MenuCode conflict.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'59')
 THROW 59003,N'Market MenuGroup conflict.',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
 VALUES(N'LAOO_MARKET',N'ระบบจัดการตลาดนัด',N'Market Management',N'ผังล็อกและการจองพื้นที่ตลาด',1,SYSUTCDATETIME(),N'BUSINESS',220,N'store_outlined',0);
DECLARE @Project bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
 VALUES(N'C',N'59',N'ระบบจัดการตลาดนัด',N'store_outlined',590,0,1,SYSUTCDATETIME(),0,0);
DECLARE @Menus TABLE(Code char(5),Name nvarchar(150),ScreenType int,Route nvarchar(150),Icon nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'59001',N'ตั้งค่าระบบตลาดนัด',2,N'market-settings',N'settings_outlined',10),
(N'59002',N'ตลาดและโซน',1,N'market-markets',N'store_outlined',20),
(N'59003',N'ผังและล็อกขายของ',1,N'market-stalls',N'grid_view_outlined',30),
(N'59004',N'ผู้ค้าและผู้สนใจ',1,N'market-traders',N'people_outlined',40),
(N'59005',N'อัตราค่าเช่าและน้ำไฟ',1,N'market-rates',N'price_change_outlined',50),
(N'59006',N'สัญญาเช่าพื้นที่',4,N'market-contracts',N'description_outlined',60),
(N'59007',N'จดมิเตอร์น้ำไฟ',4,N'market-meters',N'water_drop_outlined',70),
(N'59008',N'ยอดเรียกเก็บ',4,N'market-bills',N'receipt_long_outlined',80),
(N'59009',N'รับเงิน',4,N'market-payments',N'payments_outlined',90),
(N'59010',N'รายการค้างชำระ',3,N'market-arrears',N'warning_amber_outlined',100),
(N'59011',N'Dashboard และรายงาน',3,N'market-dashboard',N'dashboard_outlined',110);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
 SELECT Code,N'59',Name,ScreenType,Route,N'/company/'+Route,N'MARKET_'+Code,Icon,SortOrder,0,1,1,SYSUTCDATETIME(),0 FROM @Menus;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
 VALUES(@Project,N'59',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
 SELECT @Project,Code,N'59',SortOrder,1,SYSUTCDATETIME() FROM @Menus;
DECLARE @Actions TABLE(Code char(5),Action nvarchar(50));
INSERT @Actions SELECT Code,N'VIEW' FROM @Menus;
INSERT @Actions VALUES
(N'59001',N'EDIT'),
(N'59002',N'CREATE'),(N'59002',N'EDIT'),(N'59002',N'DELETE'),
(N'59003',N'CREATE'),(N'59003',N'EDIT'),(N'59003',N'DELETE'),(N'59003',N'RESERVE'),(N'59003',N'CANCEL'),(N'59003',N'BLOCK'),
(N'59004',N'CREATE'),(N'59004',N'EDIT'),(N'59004',N'DELETE'),
(N'59005',N'CREATE'),(N'59005',N'EDIT'),(N'59005',N'DELETE'),
(N'59006',N'CREATE'),(N'59006',N'EDIT'),(N'59006',N'DELETE'),
(N'59007',N'CREATE'),(N'59007',N'EDIT'),(N'59008',N'CREATE'),(N'59008',N'EDIT'),
(N'59009',N'CREATE'),(N'59009',N'EDIT'),(N'59011',N'EXPORT');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
 SELECT @Project,A.Code,M.Name,M.Route,A.Action,A.Action,A.Action,1,SYSUTCDATETIME()
 FROM @Actions A JOIN @Menus M ON M.Code=A.Code;
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive)
 VALUES(@Project,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1),
 (@Project,N'ENTERPRISE',N'องค์กร',N'ENTERPRISE',N'YEARLY',30,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
 SELECT PK.PackageID,N'MARKET_'+M.Code,1 FROM dbo.TDADProjectPackage PK CROSS JOIN @Menus M WHERE PK.ProjectID=@Project;
