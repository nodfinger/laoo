SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Run only through tools/scripts/run-migrations.ps1 after schema approval.
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_RENTAL')
 THROW 60001,N'LAOO_RENTAL already exists.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'60001' AND N'60010')
 THROW 60002,N'Rental MenuCode conflict.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'60')
 THROW 60003,N'Rental MenuGroup conflict.',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,
CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
VALUES(N'LAOO_RENTAL',N'ระบบร้านเช่า',N'Rental Management',
N'จอง รับเงิน ส่งมอบ รับคืน และคืนมัดจำ',1,SYSUTCDATETIME(),
N'BUSINESS',230,N'handyman_outlined',0);
DECLARE @Project bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,
SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
VALUES(N'C',N'60',N'ระบบร้านเช่า',N'handyman_outlined',600,0,1,SYSUTCDATETIME(),0,0);
DECLARE @Menus TABLE(Code char(5),Name nvarchar(150),ScreenType int,
Route nvarchar(150),Icon nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'60001',N'ตั้งค่าระบบร้านเช่า',2,N'rental-settings',N'settings_outlined',10),
(N'60002',N'ทะเบียนของให้เช่าและราคา',1,N'rental-items',N'construction_outlined',20),
(N'60003',N'ของว่างและปฏิทินการจอง',3,N'rental-availability',N'calendar_month_outlined',30),
(N'60004',N'จองเช่า',4,N'rental-bookings',N'event_available_outlined',40),
(N'60005',N'รับค่าเช่าและมัดจำ',4,N'rental-payments',N'payments_outlined',50),
(N'60006',N'ส่งมอบของเช่า',4,N'rental-handovers',N'outbox_outlined',60),
(N'60007',N'รับคืนและตรวจสภาพ',4,N'rental-returns',N'inventory_2_outlined',70),
(N'60008',N'หักค่าใช้จ่ายและคืนมัดจำ',4,N'rental-settlements',N'account_balance_wallet_outlined',80),
(N'60009',N'ประวัติและเอกสารเช่า',3,N'rental-history',N'history_outlined',90),
(N'60010',N'Dashboard และรายงาน',3,N'rental-dashboard',N'dashboard_outlined',100);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,
FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT Code,N'60',Name,ScreenType,Route,N'/company/'+Route,
N'RENTAL_'+Code,Icon,SortOrder,0,1,1,SYSUTCDATETIME(),0 FROM @Menus;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
VALUES(@Project,N'60',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @Project,Code,N'60',SortOrder,1,SYSUTCDATETIME() FROM @Menus;
DECLARE @Actions TABLE(Code char(5),Action nvarchar(50));
INSERT @Actions SELECT Code,N'VIEW' FROM @Menus;
INSERT @Actions VALUES
(N'60001',N'EDIT'),
(N'60002',N'CREATE'),(N'60002',N'EDIT'),(N'60002',N'DELETE'),
(N'60004',N'CREATE'),(N'60004',N'CANCEL'),
(N'60005',N'CREATE'),(N'60006',N'CREATE'),(N'60007',N'CREATE'),
(N'60008',N'APPROVE'),(N'60008',N'REFUND');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,
ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @Project,A.Code,M.Name,M.Route,A.Action,A.Action,A.Action,1,SYSUTCDATETIME()
FROM @Actions A JOIN @Menus M ON M.Code=A.Code;
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,
SortOrder,IsActive)
VALUES(@Project,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1),
(@Project,N'ENTERPRISE',N'องค์กร',N'ENTERPRISE',N'YEARLY',30,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
SELECT PK.PackageID,N'RENTAL_'+M.Code,1
FROM dbo.TDADProjectPackage PK CROSS JOIN @Menus M WHERE PK.ProjectID=@Project;
