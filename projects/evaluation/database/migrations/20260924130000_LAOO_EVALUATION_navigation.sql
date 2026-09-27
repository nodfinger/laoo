SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EVALUATION' AND IsActive=1);
IF @ProjectID IS NULL THROW 53111,N'Active LAOO_EVALUATION project is required.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'47')
  INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
  VALUES(N'C',N'47',N'ระบบประเมิน',N'rate_review_outlined',470,0,1,SYSUTCDATETIME(),0,0);
ELSE
  UPDATE dbo.TDADMenuGroup SET AudienceType=N'C',MenuGroupName=N'ระบบประเมิน',IconName=N'rate_review_outlined',SortOrder=470,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'47';

DECLARE @Menu TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
INSERT @Menu VALUES
(N'47001',N'ตั้งค่าระบบประเมิน',2,N'evaluationSettings',N'/company/evaluation-settings',N'EVALUATION_SETTINGS',N'settings_outlined',10),
(N'47002',N'แบบประเมิน',1,N'evaluationTemplates',N'/company/evaluation-templates',N'EVALUATION_TEMPLATES',N'fact_check_outlined',20),
(N'47003',N'รอบประเมิน',4,N'evaluationRounds',N'/company/evaluation-rounds',N'EVALUATION_ROUNDS',N'assignment_outlined',30),
(N'47004',N'กล่องอนุมัติรอบประเมิน',3,N'evaluationApprovals',N'/company/evaluation-approvals',N'EVALUATION_APPROVALS',N'approval_outlined',40),
(N'47005',N'งานประเมินของฉัน',3,N'myEvaluations',N'/company/my-evaluations',N'MY_EVALUATIONS',N'how_to_reg_outlined',50),
(N'47006',N'ผลประเมิน',3,N'evaluationResults',N'/company/evaluation-results',N'EVALUATION_RESULTS',N'bar_chart_outlined',60),
(N'47007',N'รายงานการประเมิน',3,N'evaluationReports',N'/company/evaluation-reports',N'EVALUATION_REPORTS',N'insights_outlined',70);

UPDATE M SET MenuGroupCode=N'47',MenuName=S.MenuName,ScreenType=S.ScreenType,RouteName=S.RouteName,RoutePath=S.RoutePath,FeatureCode=S.FeatureCode,IconName=S.IconName,SortOrder=S.SortOrder,IsVisible=1,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu M JOIN @Menu S ON S.MenuCode=M.MenuCode;
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT MenuCode,N'47',MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menu S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu M WHERE M.MenuCode=S.MenuCode);

UPDATE PM SET MenuGroupCode=N'47',SortOrder=S.SortOrder,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu PM JOIN @Menu S ON S.MenuCode=PM.MenuCode WHERE PM.ProjectID=@ProjectID;
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ProjectID,MenuCode,N'47',SortOrder,1,SYSUTCDATETIME() FROM @Menu S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu PM WHERE PM.ProjectID=@ProjectID AND PM.MenuCode=S.MenuCode);

DECLARE @Permission TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
INSERT @Permission VALUES
(N'47001',N'VIEW'),(N'47001',N'EDIT'),(N'47002',N'VIEW'),(N'47002',N'CREATE'),(N'47002',N'EDIT'),(N'47002',N'DELETE'),(N'47003',N'VIEW'),(N'47003',N'CREATE'),(N'47003',N'EDIT'),(N'47003',N'DELETE'),(N'47003',N'SUBMIT'),(N'47003',N'CANCEL'),(N'47003',N'PUBLISH'),(N'47003',N'CLOSE'),(N'47004',N'VIEW'),(N'47004',N'APPROVE'),(N'47004',N'SELF_APPROVE'),(N'47005',N'VIEW'),(N'47005',N'SUBMIT'),(N'47006',N'VIEW'),(N'47007',N'VIEW');
UPDATE P SET ScreenNameTH=M.MenuName,ScreenNameEN=M.FeatureCode,ActionNameTH=P.ActionCode,ActionNameEN=P.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission P JOIN @Permission X ON X.MenuCode=P.ScreenCode AND X.ActionCode=P.ActionCode JOIN @Menu M ON M.MenuCode=X.MenuCode WHERE P.ProjectID=@ProjectID;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,X.MenuCode,M.MenuName,M.FeatureCode,X.ActionCode,X.ActionCode,X.ActionCode,1,SYSUTCDATETIME() FROM @Permission X JOIN @Menu M ON M.MenuCode=X.MenuCode WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ProjectID AND P.ScreenCode=X.MenuCode AND P.ActionCode=X.ActionCode);

COMMIT TRANSACTION;
