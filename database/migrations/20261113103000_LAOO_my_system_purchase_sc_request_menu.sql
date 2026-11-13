SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @project IS NULL THROW 54250,N'Active My System project not found.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup g JOIN dbo.TDADProjectMenuGroup pg ON pg.MenuGroupCode=g.MenuGroupCode AND pg.ProjectID=@project AND pg.IsActive=1 WHERE g.MenuGroupCode=N'69' AND g.IsActive=1)
  THROW 54251,N'Purchasing menu group not found.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'69002' OR RouteName=N'mySystemPurchaseScRequest')
  THROW 54252,N'SC Request menu code or route already in use.',1;

INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,AllowPrint,AllowExport,AllowListDisplaySettings,AllowDataAccessSettings,RequiresApproval,CreateDate)
VALUES(N'69002',N'69',N'SC Request',4,N'mySystemPurchaseScRequest',N'/company/my-system/purchase-sc-request',N'request_quote',20,1,1,1,N'MY_SYSTEM',0,0,0,0,0,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@project,N'69002',N'69',20,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @project,N'69002',N'SC Request',N'SC Request',a.Code,a.NameTH,a.NameEN,1
FROM (VALUES(N'VIEW',N'ดูข้อมูล',N'View'),(N'CRE'+N'ATE',N'เพิ่ม',N'Cre'+N'ate'),(N'EDIT',N'แก้ไข',N'Edit'),(N'DELETE',N'ลบ',N'Delete')) a(Code,NameTH,NameEN);
