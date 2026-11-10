SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @project IS NULL THROW 54001,N'My System project not found.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'66001' AND ScreenType=4) THROW 54002,N'Travel menu not found.',1;
IF EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'67' AND MenuGroupName<>N'ระบบเบิกค่าเดินทาง') THROW 54003,N'Menu group code already used.',1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'67001' AND RouteName<>N'travelExpenseSettings') THROW 54004,N'Menu code already used.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'67')
  INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive) VALUES(N'C',N'67',N'ระบบเบิกค่าเดินทาง',N'folder',670,0,1);
IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@project AND MenuGroupCode=N'67')
  INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive) VALUES(@project,N'67',3,1);
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'67001')
  INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,CreateDate)
  VALUES(N'67001',N'67',N'กำหนดค่าระบบ',2,N'travelExpenseSettings',N'/company/my-system/travel-settings',N'settings',10,1,1,1,N'MY_SYSTEM',SYSUTCDATETIME());
-- Keep the existing document menu code and permissions while moving this one menu.
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADMainMenu') AND name=N'CK_TDADMainMenu_MenuCode' AND definition NOT LIKE N'%66001%')
BEGIN
  ALTER TABLE dbo.TDADMainMenu DROP CONSTRAINT CK_TDADMainMenu_MenuCode;
  ALTER TABLE dbo.TDADMainMenu WITH CHECK ADD CONSTRAINT CK_TDADMainMenu_MenuCode
    CHECK (MenuCode NOT LIKE '%[^0-9]%' AND (LEFT(MenuCode,2)=MenuGroupCode OR (MenuCode='66001' AND MenuGroupCode='67')));
END;
UPDATE dbo.TDADMainMenu SET MenuGroupCode=N'67',SortOrder=20 WHERE MenuCode=N'66001';
UPDATE dbo.TDADProjectMenu SET MenuGroupCode=N'67',SortOrder=20 WHERE ProjectID=@project AND MenuCode=N'66001';
IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@project AND MenuCode=N'67001')
  INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive) VALUES(@project,N'67001',N'67',10,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @project,N'67001',N'กำหนดค่าระบบ',N'Travel settings',a.Code,a.NameTH,a.NameEN,1
FROM (VALUES(N'VIEW',N'ดูข้อมูล',N'View'),(N'EDIT',N'แก้ไข',N'Edit')) a(Code,NameTH,NameEN)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission p WHERE p.ProjectID=@project AND p.ScreenCode=N'67001' AND p.ActionCode=a.Code);
IF OBJECT_ID(N'dbo.TDSTTravelVehicleRate',N'U') IS NULL
CREATE TABLE dbo.TDSTTravelVehicleRate (
 CompanyID bigint NOT NULL, VehicleTypeCode nvarchar(10) NOT NULL,
 RatePerKm decimal(12,2) NOT NULL CHECK(RatePerKm>=0),
 UpdateBy bigint NOT NULL, UpdateDate datetime2 NOT NULL CONSTRAINT DF_TravelVehicleRate_UpdateDate DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_TravelVehicleRate PRIMARY KEY(CompanyID,VehicleTypeCode)
);
COMMIT;
