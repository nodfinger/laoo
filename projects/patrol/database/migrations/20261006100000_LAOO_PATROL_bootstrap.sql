SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PATROL') THROW 57601,N'LAOO_PATROL already exists.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'56001' AND N'56012') THROW 57602,N'Patrol MenuCode conflict.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'56') THROW 57603,N'Patrol MenuGroup conflict.',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
VALUES(N'LAOO_PATROL',N'ระบบตรวจตามจุด',N'Checkpoint Patrol',N'งาน รปภ. แม่บ้าน ตรวจตามจุดและเวลาที่กำหนดโดยไม่กระทบเวลาเข้างาน',1,SYSUTCDATETIME(),N'BUSINESS',220,N'fact_check_outlined',0);
DECLARE @Project bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
VALUES(N'C',N'56',N'ระบบตรวจตามจุด',N'fact_check_outlined',560,0,1,SYSUTCDATETIME(),0,0);
DECLARE @Menus TABLE(Code char(5),Name nvarchar(150),ScreenType int,Route nvarchar(150),Icon nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'56001',N'ตั้งค่าระบบตรวจตามจุด',2,N'patrol-settings',N'settings_outlined',10),
(N'56002',N'จุดตรวจและพื้นที่',1,N'patrol-checkpoints',N'location_on_outlined',20),
(N'56003',N'อุปกรณ์และ Adapter',1,N'patrol-devices',N'devices_outlined',30),
(N'56004',N'บัตรและข้อมูลยืนยันตัวตน',1,N'patrol-credentials',N'badge_outlined',40),
(N'56005',N'แบบตรวจ Checklist',1,N'patrol-checklists',N'checklist_outlined',50),
(N'56006',N'เส้นทางตรวจ',1,N'patrol-routes',N'route_outlined',60),
(N'56007',N'ตารางตรวจและผู้รับผิดชอบ',4,N'patrol-schedules',N'calendar_month_outlined',70),
(N'56008',N'ปฏิบัติงานตรวจตามจุด',4,N'patrol-runs',N'play_circle_outline',80),
(N'56009',N'ติดตามงานตรวจ',3,N'patrol-monitor',N'monitor_heart_outlined',90),
(N'56010',N'เหตุผิดปกติและ Service',3,N'patrol-incidents',N'report_problem_outlined',100),
(N'56011',N'ประวัติและ Audit',3,N'patrol-audit',N'history_outlined',110),
(N'56012',N'Dashboard และรายงาน',3,N'patrol-dashboard',N'dashboard_outlined',120);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT Code,N'56',Name,ScreenType,Route,N'/company/'+Route,N'PATROL_'+Code,Icon,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@Project,N'56',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @Project,Code,N'56',SortOrder,1,SYSUTCDATETIME() FROM @Menus;
DECLARE @Actions TABLE(Code char(5),Action nvarchar(50)); INSERT @Actions SELECT Code,N'VIEW' FROM @Menus;
INSERT @Actions VALUES
(N'56001',N'EDIT'),
(N'56002',N'CREATE'),(N'56002',N'EDIT'),(N'56002',N'DELETE'),
(N'56003',N'CREATE'),(N'56003',N'EDIT'),(N'56003',N'DELETE'),(N'56003',N'MANAGE_DEVICE'),
(N'56004',N'CREATE'),(N'56004',N'EDIT'),(N'56004',N'DELETE'),(N'56004',N'ENROLL_CREDENTIAL'),
(N'56005',N'CREATE'),(N'56005',N'EDIT'),(N'56005',N'DELETE'),
(N'56006',N'CREATE'),(N'56006',N'EDIT'),(N'56006',N'DELETE'),
(N'56007',N'CREATE'),(N'56007',N'EDIT'),(N'56007',N'ASSIGN'),(N'56007',N'CANCEL'),
(N'56008',N'START'),(N'56008',N'CHECKPOINT'),(N'56008',N'SKIP'),(N'56008',N'COMPLETE'),(N'56008',N'CANCEL'),
(N'56009',N'ACKNOWLEDGE'),(N'56010',N'ACKNOWLEDGE'),(N'56010',N'ESCALATE'),(N'56010',N'CREATE_SERVICE'),
(N'56011',N'EXPORT'),(N'56012',N'EXPORT');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @Project,A.Code,M.Name,M.Route,A.Action,A.Action,A.Action,1,SYSUTCDATETIME() FROM @Actions A JOIN @Menus M ON M.Code=A.Code;
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive)
VALUES(@Project,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1),(@Project,N'ENTERPRISE',N'องค์กร',N'ENTERPRISE',N'YEARLY',30,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
SELECT PK.PackageID,N'PATROL_'+M.Code,1 FROM dbo.TDADProjectPackage PK CROSS JOIN @Menus M WHERE PK.ProjectID=@Project;
