SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @project IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'67' AND MenuGroupName=N'ระบบเบิกค่าเดินทาง') THROW 54020,N'Travel menu group not found.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'67002' AND (RouteName<>N'travelRouteRates' OR ScreenType<>1)) THROW 54021,N'Menu code already used.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'67002')
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,RunData,CreateDate)
 VALUES(N'67002',N'67',N'กำหนดค่าเดินทางระหว่างจุด',1,N'travelRouteRates',N'/company/my-system/travel-route-rates',N'route',15,1,1,1,N'MY_SYSTEM',0,SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@project AND MenuCode=N'67002')
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive) VALUES(@project,N'67002',N'67',15,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @project,N'67002',N'กำหนดค่าเดินทางระหว่างจุด',N'Travel route rates',a.Code,a.NameTH,a.NameEN,1
FROM (VALUES(N'VIEW',N'ดูข้อมูล',N'View'),(N'CREATE',N'เพิ่ม',N'Create'),(N'EDIT',N'แก้ไข',N'Edit'),(N'DELETE',N'ลบ',N'Delete')) a(Code,NameTH,NameEN)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission p WHERE p.ProjectID=@project AND p.ScreenCode=N'67002' AND p.ActionCode=a.Code);
IF OBJECT_ID(N'dbo.TDSTTravelRouteRate',N'U') IS NULL
 CREATE TABLE dbo.TDSTTravelRouteRate(
  Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY, CompanyID bigint NOT NULL,
  Origin nvarchar(200) NOT NULL, Destination nvarchar(200) NOT NULL,
  DistanceKm decimal(12,2) NOT NULL CHECK(DistanceKm>=0), VehicleTypeCode nvarchar(10) NOT NULL,
  Amount decimal(12,2) NOT NULL CHECK(Amount>=0), CreateBy bigint NOT NULL,
  CreateDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UpdateBy bigint NULL, UpdateDate datetime2 NULL
 );
COMMIT;
