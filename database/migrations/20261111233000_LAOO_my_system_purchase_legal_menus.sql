SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @project bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @project IS NULL THROW 54200, N'Active My System project not found.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode IN (N'69',N'70')) THROW 54201, N'Menu group code already in use.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode IN (N'69001',N'70001') OR RouteName IN (N'mySystemPurchaseSettings',N'mySystemLegalSettings')) THROW 54202, N'Menu code or route already in use.', 1;

INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive)
VALUES (N'C',N'69',N'ระบบจัดซื้อ',N'folder',690,0,1),
       (N'C',N'70',N'ระบบกฎหมาย',N'folder',700,0,1);
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive)
VALUES (@project,N'69',4,1),(@project,N'70',5,1);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,AllowPrint,AllowExport,RequiresApproval,CreateDate)
VALUES (N'69001',N'69',N'กำหนดค่าระบบ',2,N'mySystemPurchaseSettings',N'/company/my-system/purchase-settings',N'settings',10,1,1,1,N'MY_SYSTEM',0,0,0,SYSUTCDATETIME()),
       (N'70001',N'70',N'กำหนดค่าระบบ',2,N'mySystemLegalSettings',N'/company/my-system/legal-settings',N'settings',10,1,1,1,N'MY_SYSTEM',0,0,0,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES (@project,N'69001',N'69',10,1),(@project,N'70001',N'70',10,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @project, m.MenuCode, m.MenuName, m.NameEN, a.Code, a.NameTH, a.NameEN, 1
FROM (VALUES (N'69001',N'กำหนดค่าระบบ',N'Purchasing settings'),(N'70001',N'กำหนดค่าระบบ',N'Legal settings')) m(MenuCode,MenuName,NameEN)
CROSS JOIN (VALUES (N'VIEW',N'ดูข้อมูล',N'View'),(N'EDIT',N'แก้ไข',N'Edit')) a(Code,NameTH,NameEN);
