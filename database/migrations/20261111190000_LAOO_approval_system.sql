SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Core bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @Core IS NULL THROW 54100,N'Active core project is required.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_APPROVAL') THROW 54101,N'Approval project already exists; review before applying.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'68') THROW 54102,N'Approval menu group is already in use.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'68001') THROW 54103,N'Approval settings menu is already in use.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'APPROVAL_SYSTEM') THROW 54104,N'Approval feature is already in use.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.ProjectID=@Core AND PM.IsActive=1 WHERE M.MenuCode=N'10011' AND M.ScreenType=1 AND M.IsActive=1) THROW 54105,N'Existing approval menu differs from expected.',1;

INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,ProjectType,SortOrder,IconName,IsExpandedDefault,IsActive)
VALUES(N'LAOO_APPROVAL',N'ระบบการอนุมัติข้อมูล-เอกสาร',N'Data and document approval',N'กำหนดและจัดการการอนุมัติข้อมูลและเอกสาร',N'BUSINESS',680,N'approval',0,1);
DECLARE @Project bigint=SCOPE_IDENTITY();
INSERT dbo.TDADFeature(FeatureCode,FeatureName,FeatureDescription,IsActive,SortOrder)
VALUES(N'APPROVAL_SYSTEM',N'ระบบการอนุมัติข้อมูล-เอกสาร',N'กำหนดรูปแบบการอนุมัติ',1,680);
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive)
VALUES(N'C',N'68',N'การอนุมัติข้อมูล-เอกสาร',N'approval',680,0,1);
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive) VALUES(@Project,N'68',1,1);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,AllowPrint,AllowExport,CreateDate)
VALUES(N'68001',N'68',N'กำหนดค่าระบบ',2,N'companyApprovalSettings',N'/company/approval-settings',N'settings',10,1,1,1,N'APPROVAL_SYSTEM',0,0,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@Project,N'68001',N'68',10,1),(@Project,N'10011',N'68',20,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
VALUES(@Project,N'68001',N'กำหนดค่าระบบ',N'Approval settings',N'VIEW',N'ดูข้อมูล',N'View',1),
      (@Project,N'68001',N'กำหนดค่าระบบ',N'Approval settings',N'EDIT',N'แก้ไข',N'Edit',1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @Project,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive FROM dbo.TDADPermission WHERE ProjectID=@Core AND ScreenCode=N'10011';
INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT RoleGroupID,@Project,MenuCode,ActionCode,IsAllowed,N'approval-project-migration' FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@Core AND MenuCode=N'10011';
INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT RoleGroupID,@Project,N'68001',ActionCode,IsAllowed,N'approval-project-migration' FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@Core AND MenuCode=N'05001' AND ActionCode IN(N'VIEW',N'EDIT');
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT UP.UserID,@Project,NP.PermissionID,UP.IsAllowed,UP.IsActive,UP.Remark FROM dbo.TDADUserPermission UP
JOIN dbo.TDADPermission OP ON OP.PermissionID=UP.PermissionID AND OP.ProjectID=@Core
JOIN dbo.TDADPermission NP ON NP.ProjectID=@Project AND NP.ScreenCode=OP.ScreenCode AND NP.ActionCode=OP.ActionCode
WHERE UP.ProjectID=@Core AND OP.ScreenCode=N'10011';
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT UP.UserID,@Project,NP.PermissionID,UP.IsAllowed,UP.IsActive,UP.Remark FROM dbo.TDADUserPermission UP
JOIN dbo.TDADPermission OP ON OP.PermissionID=UP.PermissionID AND OP.ProjectID=@Core
JOIN dbo.TDADPermission NP ON NP.ProjectID=@Project AND NP.ScreenCode=N'68001' AND NP.ActionCode=OP.ActionCode
WHERE UP.ProjectID=@Core AND OP.ScreenCode=N'05001' AND OP.ActionCode IN(N'VIEW',N'EDIT');
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive)
VALUES(@Project,N'STANDARD',N'มาตรฐาน',N'Standard',N'STANDARD',N'MONTHLY',0,N'THB',0,10,1);
DECLARE @Package bigint=SCOPE_IDENTITY();
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled) VALUES(@Package,N'APPROVAL_SYSTEM',1);

-- Preserve access for companies with core enabled; administrators
-- can disable the new project independently afterwards.
INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText)
SELECT DISTINCT C.PartnerID,C.CompanyID,@Project,@Package,N'ACTIVE',CONVERT(date,SYSUTCDATETIME()),C.ExpireDate,1,N'รักษาการใช้งานรูปแบบอนุมัติเดิม'
FROM dbo.TDADCompanyProject C WHERE C.ProjectID=@Core AND C.IsEnabled=1 AND (C.StartDate IS NULL OR C.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (C.ExpireDate IS NULL OR C.ExpireDate>=CONVERT(date,SYSUTCDATETIME()));
INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,StartDate,ExpireDate)
SELECT @Project,PartnerID,CompanyID,1,0,StartDate,ExpireDate FROM dbo.TDADCompanyProjectSubscription WHERE ProjectID=@Project AND IsCurrent=1;
INSERT dbo.TDADCompanyFeature(ProjectID,PartnerID,CompanyID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate)
SELECT @Project,PartnerID,CompanyID,N'APPROVAL_SYSTEM',1,0,StartDate,ExpireDate FROM dbo.TDADCompanyProjectSubscription WHERE ProjectID=@Project AND IsCurrent=1;

UPDATE dbo.TDADMainMenu SET FeatureCode=N'APPROVAL_SYSTEM',UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'10011';
UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@Core AND MenuCode=N'10011';
