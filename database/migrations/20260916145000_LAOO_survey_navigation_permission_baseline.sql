/* Core-owned LAOO_SURVEY menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SURVEY' AND IsActive=1);
IF @ProjectID IS NULL THROW 52920,N'Active LAOO_SURVEY project is required.',1;
DECLARE @MenuGroupCode char(2)=N'40';
UPDATE dbo.TDADMenuGroup SET AudienceType=N'C',MenuGroupName=N'ระบบแบบสอบถาม',IconName=N'quiz_outlined',SortOrder=400,IsExpandedDefault=0,IsActive=1,ShowPermissionPoint=0,OpenOption=0,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@MenuGroupCode;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode)
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
VALUES(N'C',@MenuGroupCode,N'ระบบแบบสอบถาม',N'quiz_outlined',400,0,1,SYSUTCDATETIME(),0,0);

DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'40001',N'ตั้งค่าระบบแบบสอบถาม',2,N'surveySettings',N'/company/survey-settings',N'SURVEY_SETTINGS',N'settings_outlined',10),
(N'40002',N'แบบสอบถาม',4,N'surveys',N'/company/surveys',N'SURVEYS',N'quiz_outlined',20),
(N'40003',N'กล่องอนุมัติแบบสอบถาม',3,N'surveyApprovalInbox',N'/company/survey-approvals',N'SURVEY_APPROVAL',N'approval_outlined',30),
(N'40004',N'ส่งและติดตามแบบสอบถาม',2,N'surveyDelivery',N'/company/survey-delivery',N'SURVEY_DELIVERY',N'outgoing_mail',40),
(N'40005',N'ผลตอบและสรุปผล',3,N'surveyResults',N'/company/survey-results',N'SURVEY_RESULTS',N'analytics_outlined',50),
(N'40006',N'รายงานแบบสอบถาม',3,N'surveyReports',N'/company/survey-reports',N'SURVEY_REPORTS',N'assessment_outlined',60);
IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.ScreenType<>s.ScreenType OR ISNULL(t.RouteName,N'')<>s.RouteName OR ISNULL(t.RoutePath,N'')<>s.RoutePath)
THROW 52921,N'LAOO_SURVEY MenuCode conflicts with existing ScreenType or route.',1;
IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON(t.RouteName=s.RouteName OR t.RoutePath=s.RoutePath) AND t.MenuCode<>s.MenuCode)
THROW 52922,N'LAOO_SURVEY RouteName or RoutePath is already used.',1;
UPDATE t SET MenuGroupCode=@MenuGroupCode,MenuName=s.MenuName,ScreenType=s.ScreenType,RouteName=s.RouteName,RoutePath=s.RoutePath,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode;
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT MenuCode,@MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);

/* Menus remain unavailable until real routes, API and project migrations exist. */
UPDATE dbo.TDADProjectMenuGroup SET SortOrder=1,IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode)
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,@MenuGroupCode,1,0,SYSUTCDATETIME());
UPDATE t SET MenuGroupCode=@MenuGroupCode,SortOrder=s.SortOrder,IsActive=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode WHERE t.ProjectID=@ProjectID;
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ProjectID,MenuCode,@MenuGroupCode,SortOrder,0,SYSUTCDATETIME() FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);

DECLARE @Permissions TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
INSERT @Permissions VALUES
(N'40001',N'VIEW'),(N'40001',N'EDIT'),
(N'40002',N'VIEW'),(N'40002',N'CREATE'),(N'40002',N'EDIT'),(N'40002',N'DELETE'),(N'40002',N'SUBMIT'),(N'40002',N'CANCEL'),
(N'40003',N'VIEW'),(N'40003',N'APPROVE'),(N'40003',N'SELF_APPROVE'),
(N'40004',N'VIEW'),(N'40004',N'RESEND'),
(N'40005',N'VIEW'),(N'40006',N'VIEW');
UPDATE t SET ScreenNameTH=m.MenuName,ScreenNameEN=m.FeatureCode,ActionNameTH=CASE p.ActionCode WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล' WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล' WHEN N'SUBMIT' THEN N'ส่งอนุมัติ' WHEN N'CANCEL' THEN N'ยกเลิก' WHEN N'APPROVE' THEN N'อนุมัติ' WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง' WHEN N'RESEND' THEN N'ส่งซ้ำ' END,ActionNameEN=p.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission t JOIN @Permissions p ON p.MenuCode=t.ScreenCode AND p.ActionCode=t.ActionCode JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE t.ProjectID=@ProjectID;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,p.MenuCode,m.MenuName,m.FeatureCode,p.ActionCode,CASE p.ActionCode WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล' WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล' WHEN N'SUBMIT' THEN N'ส่งอนุมัติ' WHEN N'CANCEL' THEN N'ยกเลิก' WHEN N'APPROVE' THEN N'อนุมัติ' WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง' WHEN N'RESEND' THEN N'ส่งซ้ำ' END,p.ActionCode,1,SYSUTCDATETIME() FROM @Permissions p JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission t WHERE t.ProjectID=@ProjectID AND t.ScreenCode=p.MenuCode AND t.ActionCode=p.ActionCode);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
