SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'51001' AND N'51008' AND MenuGroupCode<>N'51') THROW 57101,N'Provider MenuCode conflict.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE (RouteName IN(N'providerSettings',N'providerLocations',N'providerServiceTypes',N'providerProfile',N'providerApprovals',N'providerReviewLinks',N'providerReviews',N'providerReports') OR RoutePath IN(N'/company/provider-settings',N'/company/provider-locations',N'/company/provider-service-types',N'/company/provider-profile',N'/company/provider-approvals',N'/company/provider-review-links',N'/company/provider-reviews',N'/company/provider-reports')) AND MenuCode NOT BETWEEN N'51001' AND N'51008') THROW 57102,N'Provider route conflict.',1;

 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PROVIDER')
  INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
  VALUES(N'LAOO_PROVIDER',N'ระบบรวมช่างและผู้ให้บริการ',N'Provider Marketplace',N'ค้นหาและจัดการผู้ให้บริการตามประเภทบริการ พื้นที่ และคะแนนรีวิว',1,SYSUTCDATETIME(),N'BUSINESS',180,N'handyman_outlined',0);
 ELSE UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบรวมช่างและผู้ให้บริการ',ProjectNameEN=N'Provider Marketplace',DescriptionText=N'ค้นหาและจัดการผู้ให้บริการตามประเภทบริการ พื้นที่ และคะแนนรีวิว',IsActive=1,ProjectType=N'BUSINESS',SortOrder=180,IconName=N'handyman_outlined',UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_PROVIDER';

 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PROVIDER');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'51')
  INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
  VALUES(N'C',N'51',N'ระบบรวมช่างและผู้ให้บริการ',N'handyman_outlined',510,0,1,SYSUTCDATETIME(),0,0);
 ELSE UPDATE dbo.TDADMenuGroup SET AudienceType=N'C',MenuGroupName=N'ระบบรวมช่างและผู้ให้บริการ',IconName=N'handyman_outlined',SortOrder=510,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'51';

 DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
 INSERT @Menus VALUES
 (N'51001',N'ตั้งค่าระบบรวมช่างและผู้ให้บริการ',2,N'providerSettings',N'/company/provider-settings',N'PROVIDER_SETTINGS',N'settings_outlined',10),
 (N'51002',N'จังหวัด อำเภอ และตำบล',1,N'providerLocations',N'/company/provider-locations',N'PROVIDER_LOCATIONS',N'location_on_outlined',20),
 (N'51003',N'ประเภทบริการ',1,N'providerServiceTypes',N'/company/provider-service-types',N'PROVIDER_SERVICE_TYPES',N'home_repair_service_outlined',30),
 (N'51004',N'โปรไฟล์และพื้นที่ให้บริการ',2,N'providerProfile',N'/company/provider-profile',N'PROVIDER_PROFILE',N'business_outlined',40),
 (N'51005',N'อนุมัติผู้ให้บริการ',3,N'providerApprovals',N'/company/provider-approvals',N'PROVIDER_APPROVALS',N'approval_outlined',50),
 (N'51006',N'ลิงก์ประเมินบริการ',1,N'providerReviewLinks',N'/company/provider-review-links',N'PROVIDER_REVIEW_LINKS',N'link_outlined',60),
 (N'51007',N'คะแนนและรีวิว',3,N'providerReviews',N'/company/provider-reviews',N'PROVIDER_REVIEWS',N'rate_review_outlined',70),
 (N'51008',N'Dashboard และรายงาน',3,N'providerReports',N'/company/provider-reports',N'PROVIDER_REPORTS',N'insights_outlined',80);
 IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.ScreenType<>s.ScreenType) THROW 57103,N'Provider ScreenType conflict.',1;
 UPDATE t SET MenuGroupCode=N'51',MenuName=s.MenuName,ScreenType=s.ScreenType,RouteName=s.RouteName,RoutePath=s.RoutePath,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode;
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
 SELECT MenuCode,N'51',MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=N'51')
  INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,N'51',1,1,SYSUTCDATETIME());
 ELSE UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=N'51';
 UPDATE t SET MenuGroupCode=N'51',SortOrder=s.SortOrder,IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode WHERE t.ProjectID=@ProjectID;
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @ProjectID,MenuCode,N'51',SortOrder,1,SYSUTCDATETIME() FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);

 DECLARE @P TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
 INSERT @P VALUES
 (N'51001',N'VIEW'),(N'51001',N'EDIT'),
 (N'51002',N'VIEW'),(N'51002',N'CREATE'),(N'51002',N'EDIT'),(N'51002',N'DELETE'),
 (N'51003',N'VIEW'),(N'51003',N'CREATE'),(N'51003',N'EDIT'),(N'51003',N'DELETE'),
 (N'51004',N'VIEW'),(N'51004',N'EDIT'),(N'51004',N'SUBMIT'),(N'51004',N'WITHDRAW'),
 (N'51005',N'VIEW'),(N'51005',N'APPROVE'),(N'51005',N'RETURN'),(N'51005',N'SUSPEND'),
 (N'51006',N'VIEW'),(N'51006',N'CREATE'),(N'51006',N'EDIT'),(N'51006',N'DELETE'),(N'51006',N'CANCEL'),
 (N'51007',N'VIEW'),(N'51007',N'MODERATE'),
 (N'51008',N'VIEW'),(N'51008',N'EXPORT');
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
