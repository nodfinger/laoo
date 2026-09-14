SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @core bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO');
DECLARE @service bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SERVICE');
IF @core IS NULL OR @service IS NULL THROW 52970,N'Required project is missing.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode NOT IN(N'14005',N'14006') AND (RouteName IN(N'serviceCustomers',N'serviceResidents') OR RoutePath IN(N'/service/customers',N'/service/residents'))) THROW 52971,N'Route collision.',1;
UPDATE dbo.TDADMainMenu SET ScreenType=3,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'13002' AND RouteName=N'companyPersons' AND RoutePath=N'/company/persons';
IF @@ROWCOUNT<>1 THROW 52972,N'Core Person menu is missing.',1;
UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'14004';
UPDATE dbo.TDADPermission SET IsActive=0 WHERE ScreenCode=N'14004';
DECLARE @m TABLE(Code nvarchar(10),Name nvarchar(200),RouteName nvarchar(100),RoutePath nvarchar(300),Icon nvarchar(100),Sort int);
INSERT @m VALUES(N'14005',N'ทะเบียนผู้ใช้บริการ',N'serviceCustomers',N'/service/customers',N'support_agent_outlined',50),(N'14006',N'ทะเบียนผู้พักอาศัย',N'serviceResidents',N'/service/residents',N'bed_outlined',60);
MERGE dbo.TDADMainMenu t USING @m s ON t.MenuCode=s.Code WHEN MATCHED THEN UPDATE SET MenuGroupCode=N'14',MenuName=s.Name,ScreenType=1,RouteName=s.RouteName,RoutePath=s.RoutePath,FeatureCode=N'SERVICE',IconName=s.Icon,SortOrder=s.Sort,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=1,UpdateDate=SYSUTCDATETIME() WHEN NOT MATCHED THEN INSERT(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) VALUES(s.Code,N'14',s.Name,1,s.RouteName,s.RoutePath,N'SERVICE',s.Icon,s.Sort,1,1,1,SYSUTCDATETIME(),1);
MERGE dbo.TDADProjectMenu t USING @m s ON t.ProjectID=@service AND t.MenuCode=s.Code WHEN MATCHED THEN UPDATE SET MenuGroupCode=N'14',SortOrder=s.Sort,IsActive=1,UpdateDate=SYSUTCDATETIME() WHEN NOT MATCHED THEN INSERT(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@service,s.Code,N'14',s.Sort,1,SYSUTCDATETIME());
UPDATE dbo.TDADPermission SET IsActive=CASE WHEN ActionCode=N'VIEW' THEN 1 ELSE 0 END WHERE ProjectID=@core AND ScreenCode=N'13002';
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) SELECT @service,s.Code,s.Name,N'Service Role Registry',a.Code,a.NameTH,a.NameEN,1,SYSUTCDATETIME() FROM @m s CROSS JOIN (VALUES(N'VIEW',N'ดู',N'View'),(N'CREATE',N'เพิ่ม',N'Create'),(N'EDIT',N'แก้ไข',N'Edit'),(N'DELETE',N'ลบ',N'Delete'))a(Code,NameTH,NameEN) WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission p WHERE p.ProjectID=@service AND p.ScreenCode=s.Code AND p.ActionCode=a.Code);
UPDATE dbo.TDADPermission SET IsActive=CASE WHEN ActionCode IN(N'VIEW',N'CREATE',N'EDIT',N'DELETE') THEN 1 ELSE 0 END WHERE ProjectID=@service AND ScreenCode IN(N'14005',N'14006');

MERGE dbo.TDADUserPermissionPointName AS T
USING (VALUES
    (N'14005',N'PERSON_EDIT',N'แก้ไขข้อมูลบุคคลกลาง',N'อนุญาตให้แก้ชื่อ ชื่อเล่น โทรศัพท์ อีเมล และสถานะที่ใช้ร่วมกัน',1),
    (N'14006',N'PERSON_EDIT',N'แก้ไขข้อมูลบุคคลกลาง',N'อนุญาตให้แก้ชื่อ ชื่อเล่น โทรศัพท์ อีเมล และสถานะที่ใช้ร่วมกัน',1)
) AS S(MenuCode,PermissionPointCode,PermissionPointName,PermissionPointDescription,SortOrder)
ON T.MenuCode=S.MenuCode AND T.PermissionPointCode=S.PermissionPointCode
WHEN MATCHED THEN UPDATE SET PermissionPointName=S.PermissionPointName,PermissionPointDescription=S.PermissionPointDescription,SortOrder=S.SortOrder,IsActive=1
WHEN NOT MATCHED THEN INSERT(MenuCode,PermissionPointCode,PermissionPointName,PermissionPointDescription,SortOrder,IsActive) VALUES(S.MenuCode,S.PermissionPointCode,S.PermissionPointName,S.PermissionPointDescription,S.SortOrder,1);
COMMIT TRANSACTION;