SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @AI bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_AI' AND IsActive=1);
IF @AI IS NULL THROW 53901, N'Active AI project is required.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'64002')
    THROW 53902, N'Menu 64002 is already in use.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@AI AND MenuCode=N'10008' AND IsActive=1)
    THROW 53903, N'Existing AI capability menu is unavailable.', 1;

INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,CreateDate)
VALUES(N'64002',N'64',N'กำหนดค่าระบบ AI',2,N'companyAiSettings',N'/company/ai-settings',N'settings',30,1,1,1,N'AI_ASSISTANT',SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@AI,N'64002',N'64',30,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
VALUES(@AI,N'64002',N'กำหนดค่าระบบ AI',N'AI system settings',N'VIEW',N'ดูข้อมูล',N'View',1),
      (@AI,N'64002',N'กำหนดค่าระบบ AI',N'AI system settings',N'EDIT',N'แก้ไข',N'Edit',1);
INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT RoleGroupID,@AI,N'64002',ActionCode,IsAllowed,N'ai-settings-migration'
FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@AI AND MenuCode=N'10008' AND ActionCode IN(N'VIEW',N'EDIT');
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT U.UserID,@AI,N.PermissionID,U.IsAllowed,U.IsActive,U.Remark
FROM dbo.TDADUserPermission U
JOIN dbo.TDADPermission O ON O.PermissionID=U.PermissionID AND O.ProjectID=@AI AND O.ScreenCode=N'10008'
JOIN dbo.TDADPermission N ON N.ProjectID=@AI AND N.ScreenCode=N'64002' AND N.ActionCode=O.ActionCode
WHERE U.ProjectID=@AI AND O.ActionCode IN(N'VIEW',N'EDIT');
