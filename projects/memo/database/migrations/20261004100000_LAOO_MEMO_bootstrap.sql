SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MEMO')
  INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault) VALUES(N'LAOO_MEMO',N'ระบบ Memo',N'Electronic Memo',N'จัดทำ อนุมัติ แจกจ่าย และพิมพ์ Memo อิเล็กทรอนิกส์',1,SYSUTCDATETIME(),N'BUSINESS',170,N'description_outlined',0);
 ELSE UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบ Memo',ProjectNameEN=N'Electronic Memo',DescriptionText=N'จัดทำ อนุมัติ แจกจ่าย และพิมพ์ Memo อิเล็กทรอนิกส์',ProjectType=N'BUSINESS',SortOrder=170,IconName=N'description_outlined',IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_MEMO';
 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MEMO'); DECLARE @Group char(2)=N'50';
 IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@Group AND AudienceType<>N'C') THROW 57001,N'Memo MenuGroupCode conflict.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@Group) INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption) VALUES(N'C',@Group,N'ระบบ Memo',N'description_outlined',500,0,1,SYSUTCDATETIME(),0,0);
 ELSE UPDATE dbo.TDADMenuGroup SET MenuGroupName=N'ระบบ Memo',IconName=N'description_outlined',SortOrder=500,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@Group;
 DECLARE @M TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
 INSERT @M VALUES
 (N'50001',N'ตั้งค่าระบบ Memo',2,N'memoSettings',N'/company/memo-settings',N'MEMO_SETTINGS',N'settings_outlined',10),
 (N'50002',N'ประเภทและเลขที่ Memo',1,N'memoTypes',N'/company/memo-types',N'MEMO_TYPES',N'format_list_numbered',20),
 (N'50003',N'สายอนุมัติ Memo',1,N'memoApprovalRoutes',N'/company/memo-approval-routes',N'MEMO_ROUTES',N'account_tree_outlined',30),
 (N'50004',N'Template Memo',1,N'memoTemplates',N'/company/memo-templates',N'MEMO_TEMPLATES',N'dashboard_customize_outlined',40),
 (N'50005',N'จัดทำ Memo',4,N'memos',N'/company/memos',N'MEMOS',N'edit_document',50),
 (N'50006',N'งานรออนุมัติ',3,N'memoApprovals',N'/company/memo-approvals',N'MEMO_APPROVALS',N'approval_outlined',60),
 (N'50007',N'กล่องรับ Memo',3,N'memoInbox',N'/company/memo-inbox',N'MEMO_INBOX',N'inbox_outlined',70),
 (N'50008',N'Memo ที่ส่งและประวัติ',3,N'memoHistory',N'/company/memo-history',N'MEMO_HISTORY',N'history_outlined',80),
 (N'50009',N'Dashboard และรายงาน',3,N'memoReports',N'/company/memo-reports',N'MEMO_REPORTS',N'insights_outlined',90);
 IF EXISTS(SELECT 1 FROM @M s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.MenuGroupCode<>@Group OR t.ScreenType<>s.ScreenType OR ISNULL(t.RouteName,N'')<>s.RouteName OR ISNULL(t.RoutePath,N'')<>s.RoutePath) THROW 57002,N'Memo MenuCode conflict.',1;
 IF EXISTS(SELECT 1 FROM @M s JOIN dbo.TDADMainMenu t ON (t.RouteName=s.RouteName OR t.RoutePath=s.RoutePath) AND t.MenuCode<>s.MenuCode) THROW 57003,N'Memo route conflict.',1;
 UPDATE t SET MenuName=s.MenuName,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @M s ON s.MenuCode=t.MenuCode;
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) SELECT MenuCode,@Group,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @M s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=@Group) INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,@Group,1,1,SYSUTCDATETIME()); ELSE UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=@Group;
 UPDATE t SET MenuGroupCode=@Group,SortOrder=s.SortOrder,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu t JOIN @M s ON s.MenuCode=t.MenuCode WHERE t.ProjectID=@ProjectID;
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @ProjectID,MenuCode,@Group,SortOrder,1,SYSUTCDATETIME() FROM @M s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);
 DECLARE @P TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
 INSERT @P VALUES
 (N'50001',N'VIEW'),(N'50001',N'EDIT'),
 (N'50002',N'VIEW'),(N'50002',N'CREATE'),(N'50002',N'EDIT'),(N'50002',N'DELETE'),
 (N'50003',N'VIEW'),(N'50003',N'CREATE'),(N'50003',N'EDIT'),(N'50003',N'DELETE'),
 (N'50004',N'VIEW'),(N'50004',N'CREATE'),(N'50004',N'EDIT'),(N'50004',N'DELETE'),
 (N'50005',N'VIEW'),(N'50005',N'CREATE'),(N'50005',N'EDIT'),(N'50005',N'DELETE'),(N'50005',N'SUBMIT'),(N'50005',N'WITHDRAW'),(N'50005',N'CANCEL'),(N'50005',N'UPLOAD'),(N'50005',N'PREVIEW'),(N'50005',N'DOWNLOAD'),(N'50005',N'PRINT'),
 (N'50006',N'VIEW'),(N'50006',N'APPROVE'),(N'50006',N'RETURN'),(N'50006',N'PREVIEW'),
 (N'50007',N'VIEW'),(N'50007',N'PREVIEW'),(N'50007',N'DOWNLOAD'),(N'50007',N'PRINT'),
 (N'50008',N'VIEW'),(N'50008',N'PREVIEW'),(N'50008',N'DOWNLOAD'),(N'50008',N'PRINT'),
 (N'50009',N'VIEW'),(N'50009',N'EXPORT');
 UPDATE t SET ScreenNameTH=m.MenuName,ScreenNameEN=m.FeatureCode,ActionNameTH=p.ActionCode,ActionNameEN=p.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission t JOIN @P p ON p.MenuCode=t.ScreenCode AND p.ActionCode=t.ActionCode JOIN @M m ON m.MenuCode=p.MenuCode WHERE t.ProjectID=@ProjectID;
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) SELECT @ProjectID,p.MenuCode,m.MenuName,m.FeatureCode,p.ActionCode,p.ActionCode,p.ActionCode,1,SYSUTCDATETIME() FROM @P p JOIN @M m ON m.MenuCode=p.MenuCode WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission t WHERE t.ProjectID=@ProjectID AND t.ScreenCode=p.MenuCode AND t.ActionCode=p.ActionCode);
 COMMIT;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
GO
