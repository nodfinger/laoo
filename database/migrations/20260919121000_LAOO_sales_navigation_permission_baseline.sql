/* Core-owned LAOO_SALES menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES' AND IsActive=1);
 IF @ProjectID IS NULL THROW 52970,N'Active LAOO_SALES project is required.',1;
 DECLARE @MenuGroupCode char(2)=N'45';
 IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode AND (AudienceType<>N'C' OR MenuGroupName<>N'ระบบบริหารงานขาย')) THROW 52971,N'LAOO_SALES MenuGroupCode conflicts with an existing group.',1;
 UPDATE dbo.TDADMenuGroup SET AudienceType=N'C',MenuGroupName=N'ระบบบริหารงานขาย',IconName=N'trending_up_outlined',SortOrder=450,IsExpandedDefault=0,IsActive=1,ShowPermissionPoint=0,OpenOption=0,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@MenuGroupCode;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode) INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption) VALUES(N'C',@MenuGroupCode,N'ระบบบริหารงานขาย',N'trending_up_outlined',450,0,1,SYSUTCDATETIME(),0,0);
 DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
 INSERT @Menus VALUES
 (N'45001',N'ตั้งค่าระบบขาย',2,N'salesSettings',N'/company/sales-settings',N'SALES_SETTINGS',N'settings_outlined',10),
 (N'45002',N'ขั้นตอนการขาย',1,N'salesPipelineStages',N'/company/sales-pipeline-stages',N'SALES_PIPELINE_STAGES',N'account_tree_outlined',20),
 (N'45003',N'ลูกค้าเป้าหมาย',1,N'salesLeads',N'/company/sales-leads',N'SALES_LEADS',N'person_search_outlined',30),
 (N'45004',N'โอกาสการขาย',1,N'salesOpportunities',N'/company/sales-opportunities',N'SALES_OPPORTUNITIES',N'handshake_outlined',40),
 (N'45005',N'กิจกรรมติดตาม',1,N'salesActivities',N'/company/sales-activities',N'SALES_ACTIVITIES',N'event_note_outlined',50),
 (N'45006',N'งานขายของฉัน',2,N'mySalesTasks',N'/company/my-sales-tasks',N'MY_SALES_TASKS',N'assignment_ind_outlined',60),
 (N'45007',N'รายงานการขาย',3,N'salesReports',N'/company/sales-reports',N'SALES_REPORTS',N'insights_outlined',70);
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.MenuGroupCode<>@MenuGroupCode OR t.ScreenType<>s.ScreenType OR ISNULL(t.RouteName,N'')<>s.RouteName OR ISNULL(t.RoutePath,N'')<>s.RoutePath) THROW 52972,N'LAOO_SALES MenuCode conflicts with existing ScreenType or route.',1;
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON (t.RouteName=s.RouteName OR t.RoutePath=s.RoutePath) AND t.MenuCode<>s.MenuCode) THROW 52973,N'LAOO_SALES RouteName or RoutePath is already used.',1;
 UPDATE t SET MenuGroupCode=@MenuGroupCode,MenuName=s.MenuName,ScreenType=s.ScreenType,RouteName=s.RouteName,RoutePath=s.RoutePath,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode;
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) SELECT MenuCode,@MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);
 /* Inactive until the Sales machine delivers real route, API and migrations. */
 UPDATE dbo.TDADProjectMenuGroup SET SortOrder=1,IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode) INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,@MenuGroupCode,1,0,SYSUTCDATETIME());
 UPDATE t SET MenuGroupCode=@MenuGroupCode,SortOrder=s.SortOrder,IsActive=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode WHERE t.ProjectID=@ProjectID;
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @ProjectID,MenuCode,@MenuGroupCode,SortOrder,0,SYSUTCDATETIME() FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);
 DECLARE @Permissions TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
 INSERT @Permissions VALUES
 (N'45001',N'VIEW'),(N'45001',N'EDIT'),(N'45002',N'VIEW'),(N'45002',N'CREATE'),(N'45002',N'EDIT'),(N'45002',N'DELETE'),
 (N'45003',N'VIEW'),(N'45003',N'CREATE'),(N'45003',N'EDIT'),(N'45003',N'DELETE'),(N'45003',N'CONVERT'),
 (N'45004',N'VIEW'),(N'45004',N'CREATE'),(N'45004',N'EDIT'),(N'45004',N'DELETE'),(N'45004',N'CLOSE'),
 (N'45005',N'VIEW'),(N'45005',N'CREATE'),(N'45005',N'EDIT'),(N'45005',N'DELETE'),(N'45006',N'VIEW'),(N'45006',N'EDIT'),(N'45007',N'VIEW');
 UPDATE t SET ScreenNameTH=m.MenuName,ScreenNameEN=m.FeatureCode,ActionNameTH=p.ActionCode,ActionNameEN=p.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission t JOIN @Permissions p ON p.MenuCode=t.ScreenCode AND p.ActionCode=t.ActionCode JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE t.ProjectID=@ProjectID;
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) SELECT @ProjectID,p.MenuCode,m.MenuName,m.FeatureCode,p.ActionCode,p.ActionCode,p.ActionCode,1,SYSUTCDATETIME() FROM @Permissions p JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission t WHERE t.ProjectID=@ProjectID AND t.ScreenCode=p.MenuCode AND t.ActionCode=p.ActionCode);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
