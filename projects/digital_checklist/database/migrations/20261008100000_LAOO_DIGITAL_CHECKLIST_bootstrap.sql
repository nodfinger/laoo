SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_DIGITAL_CHECKLIST') THROW 58001,N'Project already exists.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE TRY_CONVERT(int,MenuCode) BETWEEN 58001 AND 58010) THROW 58002,N'MenuCode conflict.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'58') THROW 58003,N'Menu group conflict.',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault) VALUES(N'LAOO_DIGITAL_CHECKLIST',N'ระบบตรวจสอบดิจิทัล',N'Digital Checklist',N'Recurring digital inspection, approval and corrective action',1,SYSUTCDATETIME(),N'BUSINESS',230,N'fact_check_outlined',0);
DECLARE @P bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption) VALUES(N'C',N'58',N'ระบบตรวจสอบดิจิทัล',N'fact_check_outlined',580,0,1,SYSUTCDATETIME(),0,0);
DECLARE @M TABLE(Code char(5),Name nvarchar(150),ST int,R nvarchar(100),I nvarchar(80),N int);
INSERT @M VALUES
(N'58001',N'ตั้งค่าระบบตรวจสอบดิจิทัล',2,N'digital-checklist-settings',N'settings_outlined',10),(N'58002',N'กลุ่มและประเภทการตรวจ',1,N'digital-checklist-groups',N'category_outlined',20),(N'58003',N'แบบตรวจสอบ',1,N'digital-checklist-templates',N'checklist_outlined',30),(N'58004',N'สายอนุมัติ',1,N'digital-checklist-workflows',N'account_tree_outlined',40),(N'58005',N'แผนตรวจและผู้รับผิดชอบ',1,N'digital-checklist-schedules',N'event_repeat_outlined',50),(N'58006',N'งานตรวจของฉัน',4,N'digital-checklist-inspections',N'fact_check_outlined',60),(N'58007',N'งานรออนุมัติ',3,N'digital-checklist-approvals',N'approval_outlined',70),(N'58008',N'งานแก้ไขและส่งแจ้งซ่อม',3,N'digital-checklist-corrective',N'build_outlined',80),(N'58009',N'ประวัติและ Audit',3,N'digital-checklist-audit',N'history_outlined',90),(N'58010',N'Dashboard และรายงาน',3,N'digital-checklist-dashboard',N'dashboard_outlined',100);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) SELECT Code,N'58',Name,ST,R,N'/company/'+R,N'DCL_'+Code,I,N,1,1,1,SYSUTCDATETIME(),0 FROM @M;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@P,N'58',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @P,Code,N'58',N,1,SYSUTCDATETIME() FROM @M;
