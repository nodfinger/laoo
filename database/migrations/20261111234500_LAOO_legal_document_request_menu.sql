SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @project IS NULL THROW 54230,N'Active My System project not found.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup g JOIN dbo.TDADProjectMenuGroup pg ON pg.MenuGroupCode=g.MenuGroupCode AND pg.ProjectID=@project AND pg.IsActive=1 WHERE g.MenuGroupCode=N'70' AND g.MenuGroupName=N'ระบบกฎหมาย' AND g.IsActive=1) THROW 54231,N'Legal menu group not found.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'70002' OR RouteName=N'mySystemLegalDocumentRequest') THROW 54232,N'Menu code or route already in use.',1;

-- Registry only: keep the menu unavailable until its screen and capabilities exist.
-- Required implementation: mandatory approval, list display settings, data access and printing; no export.
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,AllowPrint,AllowExport,AllowListDisplaySettings,AllowDataAccessSettings,RequiresApproval,CreateDate)
VALUES(N'70002',N'70',N'ขอเอกสารสำคัญ',4,N'mySystemLegalDocumentRequest',N'/company/my-system/legal-document-request',N'description',20,0,0,0,N'MY_SYSTEM',0,0,0,0,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@project,N'70002',N'70',20,0);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @project,N'70002',N'ขอเอกสารสำคัญ',N'Important document request',a.Code,a.NameTH,a.NameEN,1
FROM (VALUES(N'VIEW',N'ดูข้อมูล',N'View'),(N'CRE'+N'ATE',N'เพิ่ม',N'Cre'+N'ate'),(N'EDIT',N'แก้ไข',N'Edit'),(N'DELETE',N'ลบ',N'Delete')) a(Code,NameTH,NameEN);
