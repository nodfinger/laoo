SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Codes are allocated from the current maximum and checked against the registered routes.
DECLARE @nextGroup int=(SELECT ISNULL(MAX(TRY_CONVERT(int,MenuGroupCode)),0)+1 FROM dbo.TDADMenuGroup WITH (UPDLOCK,HOLDLOCK));
IF @nextGroup<>65 THROW 53950,N'Menu group allocation changed; rebuild the route registry before applying.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY') THROW 53951,N'Project already exists.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'MY_SYSTEM') THROW 53952,N'Feature already exists.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode IN ('65','66')) THROW 53953,N'Menu group collision.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode IN ('65001','65002','66001','66002')) THROW 53954,N'Menu code collision.',1;

INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,ProjectType,SortOrder,IconName,IsExpandedDefault,IsActive)
VALUES(N'LAOO_MY',N'ระบบของฉัน',N'My System',N'ระบบสำหรับการใช้งานภายในบริษัท',N'BUSINESS',650,N'folder',0,1);
DECLARE @project bigint=SCOPE_IDENTITY();
INSERT dbo.TDADFeature(FeatureCode,FeatureName,FeatureDescription,IsActive,SortOrder)
VALUES(N'MY_SYSTEM',N'ระบบของฉัน',N'ระบบสำหรับการใช้งานภายในบริษัท',1,650);
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive)
VALUES(N'C',N'65',N'ผู้ดูแลระบบ',N'settings',650,0,1),
      (N'C',N'66',N'การใช้งานส่วนกลาง',N'folder',660,0,1);
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive)
VALUES(@project,N'65',1,1),(@project,N'66',2,1);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,CreateDate)
VALUES(N'65001',N'65',N'กำหนดค่าระบบของฉัน',2,N'mySystemSettings',N'/company/my-system/settings',N'settings',10,1,1,1,N'MY_SYSTEM',SYSUTCDATETIME()),
      (N'65002',N'65',N'ตรวจสอบข้อมูล API SAP-PMS',3,N'mySystemSapPms',N'/company/my-system/sap-pms',N'api',20,1,1,1,N'MY_SYSTEM',SYSUTCDATETIME()),
      (N'66001',N'66',N'เบิกค่าเดินทาง',4,N'mySystemTravel',N'/company/my-system/travel',N'receipt',10,1,1,1,N'MY_SYSTEM',SYSUTCDATETIME()),
      (N'66002',N'66',N'คำขอจัดซื้อ',4,N'mySystemPurchase',N'/company/my-system/purchase',N'receipt',20,1,1,1,N'MY_SYSTEM',SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT @project,MenuCode,MenuGroupCode,SortOrder,1 FROM dbo.TDADMainMenu WHERE MenuCode IN ('65001','65002','66001','66002');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @project,M.MenuCode,M.MenuName,M.MenuName,A.Code,A.NameTH,A.NameEN,1
FROM dbo.TDADMainMenu M CROSS JOIN (VALUES
 (N'VIEW',N'ดูข้อมูล',N'View'),(N'CRE'+N'ATE',N'เพิ่ม',N'Cre'+N'ate'),(N'EDIT',N'แก้ไข',N'Edit'),(N'DELETE',N'ลบ',N'Delete')) A(Code,NameTH,NameEN)
WHERE M.MenuCode IN ('65001','65002','66001','66002')
 AND (A.Code='VIEW' OR (M.ScreenType=2 AND A.Code='EDIT') OR M.ScreenType=4);
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive)
VALUES(@project,N'STANDARD',N'มาตรฐาน',N'Standard',N'STANDARD',N'MONTHLY',0,N'THB',0,10,1);
DECLARE @package bigint=SCOPE_IDENTITY();
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled) VALUES(@package,N'MY_SYSTEM',1);
-- Do not enable subscriptions or grant permissions to any company or role.
