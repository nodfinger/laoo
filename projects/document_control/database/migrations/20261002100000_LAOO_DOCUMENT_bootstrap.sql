SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_DOCUMENT')
  INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
  VALUES(N'LAOO_DOCUMENT',N'ระบบควบคุมเอกสาร',N'Document Control',N'ทะเบียน Revision สิทธิ์เผยแพร่ การอนุมัติ และการรับทราบเอกสาร',1,SYSUTCDATETIME(),N'BUSINESS',150,N'folder_copy_outlined',0);
 ELSE
  UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบควบคุมเอกสาร',ProjectNameEN=N'Document Control',DescriptionText=N'ทะเบียน Revision สิทธิ์เผยแพร่ การอนุมัติ และการรับทราบเอกสาร',ProjectType=N'BUSINESS',SortOrder=150,IconName=N'folder_copy_outlined',IsExpandedDefault=0,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_DOCUMENT';

 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_DOCUMENT' AND IsActive=1);
 DECLARE @MenuGroupCode char(2)=N'48';
 IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode AND AudienceType<>N'C') THROW 56801,N'Document Control MenuGroupCode conflicts with another audience.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode)
  INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
  VALUES(N'C',@MenuGroupCode,N'ระบบควบคุมเอกสาร',N'folder_copy_outlined',480,0,1,SYSUTCDATETIME(),0,0);
 ELSE UPDATE dbo.TDADMenuGroup SET MenuGroupName=N'ระบบควบคุมเอกสาร',IconName=N'folder_copy_outlined',SortOrder=480,IsExpandedDefault=0,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@MenuGroupCode;

 DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
 INSERT @Menus VALUES
 (N'48001',N'ตั้งค่าระบบควบคุมเอกสาร',2,N'documentControlSettings',N'/company/document-control-settings',N'DOCUMENT_SETTINGS',N'settings_outlined',10),
 (N'48002',N'ประเภทเอกสาร',1,N'documentTypes',N'/company/document-types',N'DOCUMENT_TYPES',N'category_outlined',20),
 (N'48003',N'ทะเบียนเอกสารควบคุม',4,N'controlledDocuments',N'/company/controlled-documents',N'CONTROLLED_DOCUMENTS',N'fact_check_outlined',30),
 (N'48004',N'ตรวจทานและอนุมัติเอกสาร',3,N'documentApprovals',N'/company/document-approvals',N'DOCUMENT_APPROVALS',N'approval_outlined',40),
 (N'48005',N'เอกสารทั่วไป',1,N'generalDocuments',N'/company/general-documents',N'GENERAL_DOCUMENTS',N'description_outlined',50),
 (N'48006',N'คลังเอกสาร',3,N'documentLibrary',N'/company/document-library',N'DOCUMENT_LIBRARY',N'folder_open_outlined',60),
 (N'48007',N'เอกสารรอรับทราบ',3,N'documentAcknowledgements',N'/company/document-acknowledgements',N'DOCUMENT_ACKNOWLEDGEMENTS',N'mark_email_unread_outlined',70),
 (N'48008',N'รายงานและ Audit',3,N'documentControlReports',N'/company/document-control-reports',N'DOCUMENT_REPORTS',N'insights_outlined',80);
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.MenuGroupCode<>@MenuGroupCode OR t.ScreenType<>s.ScreenType OR ISNULL(t.RouteName,N'')<>s.RouteName OR ISNULL(t.RoutePath,N'')<>s.RoutePath) THROW 56802,N'Document Control MenuCode conflicts with existing metadata.',1;
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON (t.RouteName=s.RouteName OR t.RoutePath=s.RoutePath) AND t.MenuCode<>s.MenuCode) THROW 56803,N'Document Control route is already used.',1;
 UPDATE t SET MenuName=s.MenuName,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode;
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
 SELECT MenuCode,@MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode)
  INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,@MenuGroupCode,1,1,SYSUTCDATETIME());
 ELSE UPDATE dbo.TDADProjectMenuGroup SET SortOrder=1,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode;
 UPDATE t SET MenuGroupCode=@MenuGroupCode,SortOrder=s.SortOrder,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode WHERE t.ProjectID=@ProjectID;
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @ProjectID,MenuCode,@MenuGroupCode,SortOrder,1,SYSUTCDATETIME() FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);

 DECLARE @P TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
 INSERT @P VALUES
 (N'48001',N'VIEW'),(N'48001',N'EDIT'),
 (N'48002',N'VIEW'),(N'48002',N'CREATE'),(N'48002',N'EDIT'),(N'48002',N'DELETE'),
 (N'48003',N'VIEW'),(N'48003',N'CREATE'),(N'48003',N'EDIT'),(N'48003',N'DELETE'),(N'48003',N'SUBMIT'),(N'48003',N'PREVIEW'),(N'48003',N'DOWNLOAD'),
 (N'48004',N'VIEW'),(N'48004',N'REVIEW'),(N'48004',N'APPROVE'),(N'48004',N'RETURN'),(N'48004',N'PREVIEW'),(N'48004',N'DOWNLOAD'),
 (N'48005',N'VIEW'),(N'48005',N'CREATE'),(N'48005',N'EDIT'),(N'48005',N'DELETE'),(N'48005',N'PUBLISH'),(N'48005',N'PREVIEW'),(N'48005',N'DOWNLOAD'),
 (N'48006',N'VIEW'),(N'48006',N'PREVIEW'),(N'48006',N'DOWNLOAD'),
 (N'48007',N'VIEW'),(N'48007',N'ACKNOWLEDGE'),(N'48007',N'PREVIEW'),(N'48007',N'DOWNLOAD'),
 (N'48008',N'VIEW'),(N'48008',N'EXPORT');
 UPDATE t SET ScreenNameTH=m.MenuName,ScreenNameEN=m.FeatureCode,ActionNameTH=p.ActionCode,ActionNameEN=p.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission t JOIN @P p ON p.MenuCode=t.ScreenCode AND p.ActionCode=t.ActionCode JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE t.ProjectID=@ProjectID;
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
 SELECT @ProjectID,p.MenuCode,m.MenuName,m.FeatureCode,p.ActionCode,p.ActionCode,p.ActionCode,1,SYSUTCDATETIME() FROM @P p JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission t WHERE t.ProjectID=@ProjectID AND t.ScreenCode=p.MenuCode AND t.ActionCode=p.ActionCode);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
