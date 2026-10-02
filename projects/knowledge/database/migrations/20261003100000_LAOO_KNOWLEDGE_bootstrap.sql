SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_KNOWLEDGE')
  INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
  VALUES(N'LAOO_KNOWLEDGE',N'ระบบความรู้องค์กร',N'Knowledge Hub',N'รวบรวม ตรวจทาน เผยแพร่ ค้นหา และแลกเปลี่ยนองค์ความรู้ขององค์กร',1,SYSUTCDATETIME(),N'BUSINESS',160,N'auto_stories_outlined',0);
 ELSE
  UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบความรู้องค์กร',ProjectNameEN=N'Knowledge Hub',DescriptionText=N'รวบรวม ตรวจทาน เผยแพร่ ค้นหา และแลกเปลี่ยนองค์ความรู้ขององค์กร',ProjectType=N'BUSINESS',SortOrder=160,IconName=N'auto_stories_outlined',IsExpandedDefault=0,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_KNOWLEDGE';

 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_KNOWLEDGE' AND IsActive=1);
 DECLARE @MenuGroupCode char(2)=N'49';
 IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode AND AudienceType<>N'C') THROW 56801,N'Knowledge Hub MenuGroupCode conflicts with another audience.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode)
  INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
  VALUES(N'C',@MenuGroupCode,N'ระบบความรู้องค์กร',N'auto_stories_outlined',490,0,1,SYSUTCDATETIME(),0,0);
 ELSE UPDATE dbo.TDADMenuGroup SET MenuGroupName=N'ระบบความรู้องค์กร',IconName=N'auto_stories_outlined',SortOrder=490,IsExpandedDefault=0,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@MenuGroupCode;

 DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
 INSERT @Menus VALUES
 (N'49001',N'ตั้งค่าระบบความรู้',2,N'knowledgeSettings',N'/company/knowledge-settings',N'KNOWLEDGE_SETTINGS',N'settings_outlined',10),
 (N'49002',N'หมวดความรู้และผู้เชี่ยวชาญ',1,N'knowledgeTaxonomy',N'/company/knowledge-taxonomy',N'KNOWLEDGE_TAXONOMY',N'category_outlined',20),
 (N'49003',N'จัดการองค์ความรู้',4,N'knowledgeArticles',N'/company/knowledge-articles',N'KNOWLEDGE_ARTICLES',N'edit_note_outlined',30),
 (N'49004',N'งานตรวจทานความรู้',2,N'knowledgeReviews',N'/company/knowledge-reviews',N'KNOWLEDGE_REVIEWS',N'fact_check_outlined',40),
 (N'49005',N'คลังความรู้',3,N'knowledgeLibrary',N'/company/knowledge-library',N'KNOWLEDGE_LIBRARY',N'auto_stories_outlined',50),
 (N'49006',N'ถาม–ตอบผู้เชี่ยวชาญ',1,N'knowledgeQuestions',N'/company/knowledge-questions',N'KNOWLEDGE_QUESTIONS',N'question_answer_outlined',60),
 (N'49007',N'ความรู้ของฉัน',3,N'myKnowledge',N'/company/my-knowledge',N'MY_KNOWLEDGE',N'bookmark_outline',70),
 (N'49008',N'Dashboard และรายงาน',3,N'knowledgeReports',N'/company/knowledge-reports',N'KNOWLEDGE_REPORTS',N'insights_outlined',80);
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.MenuGroupCode<>@MenuGroupCode OR t.ScreenType<>s.ScreenType OR ISNULL(t.RouteName,N'')<>s.RouteName OR ISNULL(t.RoutePath,N'')<>s.RoutePath) THROW 56802,N'Knowledge Hub MenuCode conflicts with existing metadata.',1;
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON (t.RouteName=s.RouteName OR t.RoutePath=s.RoutePath) AND t.MenuCode<>s.MenuCode) THROW 56803,N'Knowledge Hub route is already used.',1;
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
 (N'49001',N'VIEW'),(N'49001',N'EDIT'),
 (N'49002',N'VIEW'),(N'49002',N'CREATE'),(N'49002',N'EDIT'),(N'49002',N'DELETE'),
(N'49003',N'VIEW'),(N'49003',N'CREATE'),(N'49003',N'EDIT'),(N'49003',N'DELETE'),(N'49003',N'SUBMIT'),(N'49003',N'ARCHIVE'),(N'49003',N'UPLOAD'),(N'49003',N'PREVIEW'),(N'49003',N'DOWNLOAD'),
(N'49004',N'VIEW'),(N'49004',N'REVIEW'),(N'49004',N'RETURN'),(N'49004',N'PUBLISH'),(N'49004',N'PREVIEW'),
(N'49005',N'VIEW'),(N'49005',N'PREVIEW'),(N'49005',N'DOWNLOAD'),(N'49005',N'FEEDBACK'),(N'49005',N'COMMENT'),(N'49005',N'FOLLOW'),
(N'49006',N'VIEW'),(N'49006',N'CREATE'),(N'49006',N'EDIT'),(N'49006',N'DELETE'),(N'49006',N'ANSWER'),(N'49006',N'ACCEPT'),(N'49006',N'CONVERT'),(N'49006',N'COMMENT'),
(N'49007',N'VIEW'),(N'49007',N'FOLLOW'),(N'49007',N'PREVIEW'),
 (N'49008',N'VIEW'),(N'49008',N'EXPORT');
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
