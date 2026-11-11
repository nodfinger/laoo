SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_APPROVAL' AND IsActive=1);
IF @Project IS NULL THROW 54220,N'Approval project is missing.',1;
IF COL_LENGTH(N'dbo.TDADMainMenu',N'RequiresApproval') IS NULL THROW 54221,N'Approval menu flag is missing.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'68002' AND (RouteName<>N'companyApprovalAssignment' OR ScreenType<>3))
    THROW 54222,N'Approval assignment menu code is already in use.',1;

IF OBJECT_ID(N'dbo.TDSTMenuApprovalAssignment',N'U') IS NULL
CREATE TABLE dbo.TDSTMenuApprovalAssignment (
    CompanyID bigint NOT NULL,
    MenuCode char(5) NOT NULL,
    PatternCode nvarchar(50) NOT NULL,
    UpdateBy bigint NOT NULL,
    UpdateDate datetime2 NOT NULL CONSTRAINT DF_MenuApprovalAssignment_Date DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_MenuApprovalAssignment PRIMARY KEY(CompanyID,MenuCode),
    CONSTRAINT FK_MenuApprovalAssignment_Menu FOREIGN KEY(MenuCode) REFERENCES dbo.TDADMainMenu(MenuCode),
    CONSTRAINT FK_MenuApprovalAssignment_Pattern FOREIGN KEY(CompanyID,PatternCode) REFERENCES dbo.TDSTApprovalPatternCatalog(CompanyID,PatternCode)
);

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'68002')
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,AllowPrint,AllowExport,AllowListDisplaySettings,CreateDate)
VALUES(N'68002',N'68',N'กำหนดการอนุมัติ',3,N'companyApprovalAssignment',N'/company/approval-assignment',N'approval',30,1,1,1,N'APPROVAL_SYSTEM',0,0,0,SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@Project AND MenuCode=N'68002')
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive) VALUES(@Project,N'68002',N'68',30,1);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@Project AND ScreenCode=N'68002' AND ActionCode=N'VIEW')
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
VALUES(@Project,N'68002',N'กำหนดการอนุมัติ',N'Approval assignment',N'VIEW',N'ดูข้อมูล',N'View',1);

INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT RP.RoleGroupID,@Project,N'68002',N'VIEW',RP.IsAllowed,N'approval-assignment-migration'
FROM dbo.TDADRoleGroupPermission RP
WHERE RP.ProjectID=@Project AND RP.MenuCode=N'10011' AND RP.ActionCode=N'VIEW'
AND NOT EXISTS(SELECT 1 FROM dbo.TDADRoleGroupPermission X WHERE X.RoleGroupID=RP.RoleGroupID AND X.ProjectID=@Project AND X.MenuCode=N'68002' AND X.ActionCode=N'VIEW');
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT UP.UserID,@Project,NewP.PermissionID,UP.IsAllowed,UP.IsActive,UP.Remark
FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission OldP ON OldP.PermissionID=UP.PermissionID AND OldP.ProjectID=@Project AND OldP.ScreenCode=N'10011' AND OldP.ActionCode=N'VIEW'
JOIN dbo.TDADPermission NewP ON NewP.ProjectID=@Project AND NewP.ScreenCode=N'68002' AND NewP.ActionCode=N'VIEW'
WHERE UP.ProjectID=@Project AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission X WHERE X.UserID=UP.UserID AND X.ProjectID=@Project AND X.PermissionID=NewP.PermissionID);
