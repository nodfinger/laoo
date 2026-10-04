SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Executed transactionally by the migration runner, only after migration approval.
IF OBJECT_ID(N'dbo.TDSCStudent',N'U') IS NULL THROW 57301,N'LAOO_SCHOOL is required.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'53001' AND N'53012')
 THROW 57302,N'School Food MenuCode conflict. Do not overwrite existing menus.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'53')
 THROW 57303,N'School Food MenuGroup conflict.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SCHOOL_FOOD')
 THROW 57304,N'School Food Project already exists outside this migration.',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
 VALUES(N'LAOO_SCHOOL_FOOD',N'ระบบขายอาหารในโรงเรียน',N'School Food',N'ร้านค้า Wallet นักเรียน และประวัติการซื้อ เชื่อม LAOO_SCHOOL',1,SYSUTCDATETIME(),N'BUSINESS',200,N'restaurant_outlined',0);
DECLARE @Project bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
 VALUES(N'C',N'53',N'ระบบขายอาหารในโรงเรียน',N'restaurant_outlined',530,0,1,SYSUTCDATETIME(),0,0);
DECLARE @Menus TABLE(Code char(5),Name nvarchar(150),ScreenType int,Route nvarchar(150),Icon nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'53001',N'ตั้งค่าระบบขายอาหารในโรงเรียน',2,N'school-food-settings',N'settings_outlined',10),
(N'53002',N'ข้อมูลร้านค้าในโรงเรียน',1,N'school-food-shops',N'storefront_outlined',20),
(N'53003',N'สินค้าที่ขายแยกตามร้านค้า',2,N'school-food-items',N'inventory_2_outlined',30),
(N'53004',N'กำหนดเปอร์เซ็นต์หักยอดขาย',2,N'school-food-commission',N'percent',40),
(N'53005',N'บัตรและลายนิ้วมือนักเรียน',1,N'school-food-identifiers',N'badge_outlined',50),
(N'53006',N'โอนและรับสต๊อกร้านค้า',4,N'school-food-transfers',N'swap_horiz',60),
(N'53007',N'Wallet และการเติมเงิน',4,N'school-food-wallet',N'account_balance_wallet_outlined',70),
(N'53008',N'ขายหน้าร้าน',4,N'school-food-pos',N'point_of_sale',80),
(N'53009',N'ประวัติขายและคืนสินค้า',4,N'school-food-sales',N'receipt_long_outlined',90),
(N'53010',N'ประวัติการซื้อของนักเรียน',3,N'school-food-students',N'history',100),
(N'53011',N'กระทบยอดร้านค้า',3,N'school-food-settlements',N'fact_check_outlined',110),
(N'53012',N'Dashboard และรายงาน',3,N'school-food-dashboard',N'dashboard_outlined',120);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
 SELECT Code,N'53',Name,ScreenType,Route,N'/company/'+Route,N'SCHOOL_FOOD_'+Code,Icon,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@Project,N'53',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
 SELECT @Project,Code,N'53',SortOrder,1,SYSUTCDATETIME() FROM @Menus;
DECLARE @Actions TABLE(Code char(5),Action nvarchar(50));
INSERT @Actions SELECT Code,N'VIEW' FROM @Menus;
INSERT @Actions VALUES
(N'53001',N'EDIT'),(N'53002',N'CREATE'),(N'53002',N'EDIT'),(N'53002',N'DELETE'),
(N'53003',N'EDIT'),(N'53004',N'EDIT'),(N'53005',N'CREATE'),(N'53005',N'EDIT'),(N'53005',N'DELETE'),
(N'53005',N'MANAGE_DEVICE'),(N'53005',N'MANAGE_CREDENTIAL'),
(N'53006',N'CREATE'),(N'53006',N'EDIT'),(N'53006',N'DELETE'),(N'53006',N'TRANSFER'),(N'53006',N'RECEIVE'),
(N'53007',N'TOPUP'),(N'53007',N'ADJUST'),(N'53008',N'SALE'),(N'53009',N'REFUND'),
(N'53010',N'EXPORT'),(N'53011',N'EXPORT'),(N'53012',N'EXPORT');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
 SELECT @Project,A.Code,M.Name,M.Route,A.Action,A.Action,A.Action,1,SYSUTCDATETIME() FROM @Actions A JOIN @Menus M ON M.Code=A.Code;
-- Separate package master. Partner assigns subscriptions; no automatic entitlement grants.
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive)
 VALUES(@Project,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1),
 (@Project,N'ENTERPRISE',N'องค์กร',N'ENTERPRISE',N'YEARLY',30,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
 SELECT PK.PackageID,N'SCHOOL_FOOD_'+M.Code,1 FROM dbo.TDADProjectPackage PK CROSS JOIN @Menus M WHERE PK.ProjectID=@Project;
