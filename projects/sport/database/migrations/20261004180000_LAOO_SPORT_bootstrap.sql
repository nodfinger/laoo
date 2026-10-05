SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Transactional via the central migration runner. Do not execute without approval.
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SPORT')
 THROW 57401,N'LAOO_SPORT already exists.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'54001' AND N'54011')
 THROW 57402,N'Sport MenuCode conflict.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'54')
 THROW 57403,N'Sport MenuGroup conflict.',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
 VALUES(N'LAOO_SPORT',N'ระบบสมาชิกฟิตเนสและสนามกีฬา',N'Sport Membership',N'สมาชิก แพ็กเกจ จองสนาม เช็กอิน และรายงาน',1,SYSUTCDATETIME(),N'BUSINESS',210,N'sports_basketball_outlined',0);
DECLARE @Project bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
 VALUES(N'C',N'54',N'ระบบสมาชิกและสนามกีฬา',N'sports_basketball_outlined',540,0,1,SYSUTCDATETIME(),0,0);
DECLARE @Menus TABLE(Code char(5),Name nvarchar(150),ScreenType int,Route nvarchar(150),Icon nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'54001',N'ตั้งค่าระบบกีฬา',2,N'sport-settings',N'settings_outlined',10),
(N'54002',N'ประเภทกีฬา',1,N'sport-types',N'sports_outlined',20),
(N'54003',N'สนามและพื้นที่',1,N'sport-facilities',N'stadium_outlined',30),
(N'54004',N'ระดับสมาชิก',1,N'sport-levels',N'workspace_premium_outlined',40),
(N'54005',N'แพ็กเกจและราคา',1,N'sport-packages',N'card_membership_outlined',50),
(N'54006',N'ข้อมูลสมาชิก',1,N'sport-members',N'people_outline',60),
(N'54007',N'สมัครและต่ออายุ',4,N'sport-enrollments',N'receipt_long_outlined',70),
(N'54008',N'จองสนาม',1,N'sport-bookings',N'event_available_outlined',80),
(N'54009',N'เช็กอินเข้าเล่น',3,N'sport-checkins',N'how_to_reg_outlined',90),
(N'54010',N'กฎราคา POS',2,N'sport-pos-pricing',N'price_change_outlined',100),
(N'54011',N'Dashboard และรายงาน',3,N'sport-dashboard',N'dashboard_outlined',110);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
 SELECT Code,N'54',Name,ScreenType,Route,N'/company/'+Route,N'SPORT_'+Code,Icon,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
 VALUES(@Project,N'54',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
 SELECT @Project,Code,N'54',SortOrder,1,SYSUTCDATETIME() FROM @Menus;
DECLARE @Actions TABLE(Code char(5),Action nvarchar(50));
INSERT @Actions SELECT Code,N'VIEW' FROM @Menus;
INSERT @Actions VALUES
(N'54001',N'EDIT'),
(N'54002',N'CREATE'),(N'54002',N'EDIT'),(N'54002',N'DELETE'),
(N'54003',N'CREATE'),(N'54003',N'EDIT'),(N'54003',N'DELETE'),
(N'54004',N'CREATE'),(N'54004',N'EDIT'),(N'54004',N'DELETE'),
(N'54005',N'CREATE'),(N'54005',N'EDIT'),(N'54005',N'DELETE'),
(N'54006',N'CREATE'),(N'54006',N'EDIT'),(N'54006',N'DELETE'),(N'54006',N'MANAGE_CREDENTIAL'),
(N'54007',N'CREATE'),(N'54007',N'EDIT'),(N'54007',N'RENEW'),(N'54007',N'RECORD_PAYMENT'),
(N'54008',N'CREATE'),(N'54008',N'EDIT'),(N'54008',N'DELETE'),(N'54008',N'CANCEL'),
(N'54009',N'CHECK_IN'),(N'54009',N'MARK_NO_SHOW'),
(N'54010',N'EDIT'),(N'54011',N'EXPORT');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
 SELECT @Project,A.Code,M.Name,M.Route,A.Action,A.Action,A.Action,1,SYSUTCDATETIME()
 FROM @Actions A JOIN @Menus M ON M.Code=A.Code;
-- Packages are separately assigned by Partner; never auto-grant company access.
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive)
 VALUES(@Project,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1),
 (@Project,N'ENTERPRISE',N'องค์กร',N'ENTERPRISE',N'YEARLY',30,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
 SELECT PK.PackageID,N'SPORT_'+M.Code,1 FROM dbo.TDADProjectPackage PK CROSS JOIN @Menus M WHERE PK.ProjectID=@Project;
