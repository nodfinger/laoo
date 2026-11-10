/* Prepare a package-controlled AI project without changing company AI settings.
   The migration runner supplies the transaction. Existing permissions are copied. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Core bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @Core IS NULL THROW 53800, N'Active core project is required.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_AI')
    THROW 53801, N'LAOO_AI already exists; review its configuration.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'64')
    THROW 53802, N'Menu group 64 is already in use.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'AI_ASSISTANT')
    THROW 53803, N'AI_ASSISTANT feature already exists.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'64001')
    THROW 53806, N'Menu 64001 is already in use.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode
    WHERE M.MenuCode=N'10008' AND M.ScreenType=1 AND M.IsActive=1 AND PM.ProjectID=@Core AND PM.IsActive=1)
    THROW 53804, N'Existing AI capability menu does not match expectations.', 1;

INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,ProjectType,SortOrder,IconName,IsExpandedDefault,IsActive)
VALUES(N'LAOO_AI',N'ระบบ AI',N'AI System',N'จัดการและใช้งาน AI ภายในองค์กร',N'BUSINESS',640,N'smart_toy',0,1);
DECLARE @AI bigint=SCOPE_IDENTITY();
INSERT dbo.TDADFeature(FeatureCode,FeatureName,FeatureDescription,IsActive,SortOrder)
VALUES(N'AI_ASSISTANT',N'ระบบ AI',N'จัดการและใช้งาน AI ภายในองค์กร',1,640);
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive)
VALUES(N'C',N'64',N'จัดการ AI',N'smart_toy',640,0,1);
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive) VALUES(@AI,N'64',1,1);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT @AI,MenuCode,N'64',SortOrder,1 FROM dbo.TDADProjectMenu WHERE ProjectID=@Core AND MenuCode=N'10008' AND IsActive=1;
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,CreateDate)
VALUES(N'64001',N'64',N'ทดลองคำถาม AI',3,N'companyAiIntentTest',N'/company/ai-intent-test',N'psychology',20,1,1,1,N'AI_ASSISTANT',SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive) VALUES(@AI,N'64001',N'64',20,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
VALUES(@AI,N'64001',N'ทดลองคำถาม AI',N'AI intent test',N'VIEW',N'ดูข้อมูล',N'View',1);

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @AI,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive
FROM dbo.TDADPermission WHERE ProjectID=@Core AND ScreenCode=N'10008';
/* Older deployments may contain role grants without permission definitions. */
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @AI,N'10008',N'จัดการความสามารถ AI',N'AI capabilities',V.Code,V.NameTH,V.NameEN,1
FROM (VALUES (N'VIEW',N'ดูข้อมูล',N'View'),(N'EDIT',N'แก้ไข',N'Edit')) V(Code,NameTH,NameEN)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@AI AND P.ScreenCode=N'10008' AND P.ActionCode=V.Code);
INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT RoleGroupID,@AI,MenuCode,ActionCode,IsAllowed,N'ai-project-migration'
FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@Core AND MenuCode=N'10008';
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT UP.UserID,@AI,NP.PermissionID,UP.IsAllowed,UP.IsActive,UP.Remark
FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission OP ON OP.PermissionID=UP.PermissionID AND OP.ProjectID=@Core
JOIN dbo.TDADPermission NP ON NP.ProjectID=@AI AND NP.ScreenCode=OP.ScreenCode AND NP.ActionCode=OP.ActionCode
WHERE UP.ProjectID=@Core AND OP.ScreenCode=N'10008';

INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive)
VALUES(@AI,N'STANDARD',N'มาตรฐาน',N'Standard',N'STANDARD',N'MONTHLY',0,N'THB',0,10,1);
DECLARE @Package bigint=SCOPE_IDENTITY();
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled) VALUES(@Package,N'AI_ASSISTANT',1);

/* Only companies with existing AI enabled get an active subscription. */
INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText)
SELECT PartnerID,CompanyID,@AI,@Package,N'ACTIVE',CONVERT(date,SYSUTCDATETIME()),NULL,1,N'รักษาการใช้งาน AI เดิม'
FROM dbo.TDSTCompanySetUp WHERE OwnerType=N'C' AND IsActive=1 AND AiChatEnabled=1 AND PartnerID IS NOT NULL AND CompanyID IS NOT NULL;
INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,StartDate,ExpireDate)
SELECT @AI,PartnerID,CompanyID,1,0,CONVERT(date,SYSUTCDATETIME()),NULL
FROM dbo.TDSTCompanySetUp WHERE OwnerType=N'C' AND IsActive=1 AND AiChatEnabled=1 AND PartnerID IS NOT NULL AND CompanyID IS NOT NULL;
INSERT dbo.TDADCompanyFeature(ProjectID,PartnerID,CompanyID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate)
SELECT @AI,PartnerID,CompanyID,N'AI_ASSISTANT',1,0,CONVERT(date,SYSUTCDATETIME()),NULL
FROM dbo.TDSTCompanySetUp WHERE OwnerType=N'C' AND IsActive=1 AND AiChatEnabled=1 AND PartnerID IS NOT NULL AND CompanyID IS NOT NULL;

IF EXISTS(SELECT RoleGroupID,MenuCode,ActionCode,IsAllowed FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@Core AND MenuCode=N'10008'
          EXCEPT SELECT RoleGroupID,MenuCode,ActionCode,IsAllowed FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@AI AND MenuCode=N'10008')
    THROW 53805, N'Existing AI role permissions were not preserved.', 1;
UPDATE dbo.TDADMainMenu SET FeatureCode=N'AI_ASSISTANT',UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'10008';
UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@Core AND MenuCode=N'10008';
