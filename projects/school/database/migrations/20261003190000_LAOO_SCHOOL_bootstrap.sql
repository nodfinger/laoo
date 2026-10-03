SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'52001' AND N'52014' AND MenuGroupCode<>N'52')
  THROW 57201,N'School MenuCode conflict.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SCHOOL')
  INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
  VALUES(N'LAOO_SCHOOL',N'ระบบบันทึกเวลาโรงเรียน',N'School Attendance',N'บันทึกเวลาเข้าออก เช็กชื่อรายคาบ ข่าวสาร และมุมผู้ปกครอง',1,SYSUTCDATETIME(),N'BUSINESS',190,N'school_outlined',0);
 ELSE UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบบันทึกเวลาโรงเรียน',ProjectNameEN=N'School Attendance',IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_SCHOOL';
 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SCHOOL');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'52')
  INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
  VALUES(N'C',N'52',N'ระบบบันทึกเวลาโรงเรียน',N'school_outlined',520,0,1,SYSUTCDATETIME(),0,0);
 ELSE UPDATE dbo.TDADMenuGroup SET MenuGroupName=N'ระบบบันทึกเวลาโรงเรียน',IconName=N'school_outlined',IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'52';
 DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
 INSERT @Menus VALUES
 (N'52001',N'ตั้งค่าระบบโรงเรียน',2,N'schoolSettings',N'/company/school-settings',N'SCHOOL_SETTINGS',N'settings_outlined',10),
 (N'52002',N'ระดับชั้น',1,N'schoolLevels',N'/company/school-levels',N'SCHOOL_LEVELS',N'account_tree_outlined',20),
 (N'52003',N'รอบเรียนและเวลาเข้าออก',1,N'schoolRounds',N'/company/school-rounds',N'SCHOOL_ROUNDS',N'schedule_outlined',30),
 (N'52004',N'วันหยุดโรงเรียน',1,N'schoolHolidays',N'/company/school-holidays',N'SCHOOL_HOLIDAYS',N'event_busy_outlined',40),
 (N'52005',N'วิชา ห้องเรียน และตารางเรียน',1,N'schoolAcademics',N'/company/school-academics',N'SCHOOL_ACADEMICS',N'menu_book_outlined',50),
 (N'52006',N'ข้อมูลนักเรียน',1,N'schoolStudents',N'/company/school-students',N'SCHOOL_STUDENTS',N'badge_outlined',60),
 (N'52007',N'ข้อมูลผู้ปกครอง',1,N'schoolGuardians',N'/company/school-guardians',N'SCHOOL_GUARDIANS',N'family_restroom_outlined',70);
 INSERT @Menus VALUES
 (N'52008',N'ลงเวลาเข้า–ออกโรงเรียน',4,N'schoolAttendance',N'/company/school-attendance',N'SCHOOL_ATTENDANCE',N'how_to_reg_outlined',80),
 (N'52009',N'เช็กชื่อรายคาบ',4,N'schoolRollCall',N'/company/school-roll-call',N'SCHOOL_ROLL_CALL',N'fact_check_outlined',90),
 (N'52010',N'ข่าวสารถึงผู้ปกครอง',1,N'schoolNews',N'/company/school-news',N'SCHOOL_NEWS',N'campaign_outlined',100),
 (N'52011',N'รายงานเวลาเข้า–ออก',3,N'schoolDailyReport',N'/company/school-daily-report',N'SCHOOL_DAILY_REPORT',N'assessment_outlined',110),
 (N'52012',N'รายงานเวลาเรียนรายวิชา',3,N'schoolPeriodReport',N'/company/school-period-report',N'SCHOOL_PERIOD_REPORT',N'analytics_outlined',120),
 (N'52013',N'Dashboard โรงเรียน',3,N'schoolDashboard',N'/company/school-dashboard',N'SCHOOL_DASHBOARD',N'dashboard_outlined',130),
 (N'52014',N'มุมผู้ปกครอง',3,N'schoolGuardianPortal',N'/company/school-guardian-portal',N'SCHOOL_GUARDIAN_PORTAL',N'family_restroom_outlined',140);
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.ScreenType<>s.ScreenType)
  THROW 57202,N'School ScreenType conflict.',1;
 UPDATE t SET MenuGroupCode=N'52',MenuName=s.MenuName,ScreenType=s.ScreenType,RouteName=s.RouteName,RoutePath=s.RoutePath,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode;
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
 SELECT MenuCode,N'52',MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=N'52')
  INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,N'52',1,1,SYSUTCDATETIME());
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
 SELECT @ProjectID,MenuCode,N'52',SortOrder,1,SYSUTCDATETIME() FROM @Menus s
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);
 DECLARE @P TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
 INSERT @P
 SELECT MenuCode,N'VIEW' FROM @Menus;
 INSERT @P VALUES
 (N'52001',N'EDIT'),
 (N'52002',N'CREATE'),(N'52002',N'EDIT'),(N'52002',N'DELETE'),
 (N'52003',N'CREATE'),(N'52003',N'EDIT'),(N'52003',N'DELETE'),
 (N'52004',N'CREATE'),(N'52004',N'EDIT'),(N'52004',N'DELETE'),
 (N'52005',N'CREATE'),(N'52005',N'EDIT'),(N'52005',N'DELETE'),
 (N'52006',N'CREATE'),(N'52006',N'EDIT'),(N'52006',N'DELETE'),
 (N'52007',N'CREATE'),(N'52007',N'EDIT'),(N'52007',N'DELETE'),
 (N'52008',N'CREATE'),(N'52008',N'EDIT'),(N'52009',N'CREATE'),(N'52009',N'EDIT'),
 (N'52010',N'CREATE'),(N'52010',N'EDIT'),(N'52010',N'DELETE'),(N'52010',N'PUBLISH'),
 (N'52011',N'EXPORT'),(N'52012',N'EXPORT'),(N'52013',N'EXPORT');
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
 SELECT @ProjectID,p.MenuCode,m.MenuName,m.FeatureCode,p.ActionCode,p.ActionCode,p.ActionCode,1,SYSUTCDATETIME()
 FROM @P p JOIN @Menus m ON m.MenuCode=p.MenuCode
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission t WHERE t.ProjectID=@ProjectID AND t.ScreenCode=p.MenuCode AND t.ActionCode=p.ActionCode);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
