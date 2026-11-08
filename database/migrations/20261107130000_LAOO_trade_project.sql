/* Move the existing sales menus to a separately subscribed business project.
   This migration changes configuration and grants only; inventory data stays put.
   The migration runner supplies the transaction. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Core bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @Core IS NULL THROW 53300, N'Active core project is required.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TRADE')
    THROW 53301, N'LAOO_TRADE already exists; review its configuration.', 1;
IF (SELECT COUNT(*) FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode
    WHERE PM.ProjectID=@Core AND PM.IsActive=1 AND M.MenuGroupCode=N'09' AND M.MenuCode BETWEEN N'09001' AND N'09027' AND M.IsActive=1)<>25
    THROW 53302, N'The sales menu set differs from the expected twenty-five menus.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'SALES' AND IsActive=1)
    THROW 53303, N'The sales feature is required.', 1;

INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,ProjectType,SortOrder,IconName,IsExpandedDefault,IsActive)
VALUES(N'LAOO_TRADE',N'ระบบบริหารสต๊อก',N'Sales',N'บริหารสินค้า วัสดุ และคลังสินค้า',N'BUSINESS',80,N'point_of_sale',0,1);
DECLARE @Trade bigint=SCOPE_IDENTITY();
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive)
SELECT @Trade,MenuGroupCode,SortOrder,1 FROM dbo.TDADProjectMenuGroup
WHERE ProjectID=@Core AND MenuGroupCode=N'09' AND IsActive=1;
IF @@ROWCOUNT<>1 THROW 53304, N'Inventory menu group is not active in the core project.', 1;
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT @Trade,PM.MenuCode,PM.MenuGroupCode,PM.SortOrder,1
FROM dbo.TDADProjectMenu PM JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode
WHERE PM.ProjectID=@Core AND PM.IsActive=1 AND M.MenuGroupCode=N'09' AND M.MenuCode BETWEEN N'09001' AND N'09027';

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @Trade,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive
FROM dbo.TDADPermission WHERE ProjectID=@Core AND ScreenCode BETWEEN N'09001' AND N'09027';
INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT RP.RoleGroupID,@Trade,RP.MenuCode,RP.ActionCode,RP.IsAllowed,N'trade-project-migration'
FROM dbo.TDADRoleGroupPermission RP WHERE RP.ProjectID=@Core AND RP.MenuCode BETWEEN N'09001' AND N'09027';
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT UP.UserID,@Trade,NP.PermissionID,UP.IsAllowed,UP.IsActive,UP.Remark
FROM dbo.TDADUserPermission UP
JOIN dbo.TDADPermission OP ON OP.PermissionID=UP.PermissionID AND OP.ProjectID=@Core
JOIN dbo.TDADPermission NP ON NP.ProjectID=@Trade AND NP.ScreenCode=OP.ScreenCode AND NP.ActionCode=OP.ActionCode
WHERE UP.ProjectID=@Core AND OP.ScreenCode BETWEEN N'09001' AND N'09027';

/* Keep the original point grants for sessions using Core and copy them for Stock sessions. */
INSERT dbo.TDADUserPermissionPoint(ProjectID,PartnerID,CompanyID,EmployeeID,MenuCode,PermissionPointCode,IsAllowed,IsActive,EffectiveFrom,EffectiveTo,CreatedBy)
SELECT @Trade,PartnerID,CompanyID,EmployeeID,MenuCode,PermissionPointCode,IsAllowed,IsActive,EffectiveFrom,EffectiveTo,CreatedBy
FROM dbo.TDADUserPermissionPoint WHERE ProjectID=@Core AND MenuCode BETWEEN N'09001' AND N'09027';

INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive)
VALUES(@Trade,N'STANDARD',N'มาตรฐาน',N'Standard',N'STANDARD',N'MONTHLY',0,N'THB',0,10,1);
DECLARE @Package bigint=SCOPE_IDENTITY();
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled) VALUES(@Package,N'SALES',1);

/* A currently active Core subscription already included inventory. Preserve it. */
SELECT CP.CompanyID,CP.PartnerID,CASE WHEN CF.StartDate>COALESCE(CP.StartDate,CONVERT(date,SYSUTCDATETIME())) THEN CF.StartDate ELSE COALESCE(CP.StartDate,CONVERT(date,SYSUTCDATETIME())) END AS StartDate, CASE WHEN CP.ExpireDate IS NULL THEN CF.ExpireDate WHEN CF.ExpireDate IS NULL OR CP.ExpireDate<CF.ExpireDate THEN CP.ExpireDate ELSE CF.ExpireDate END AS ExpireDate, CP.IsTrial
INTO #ExistingCompanies
FROM dbo.TDADCompanyProject CP JOIN dbo.TDADCompanyFeature CF ON CF.ProjectID=CP.ProjectID AND CF.CompanyID=CP.CompanyID AND CF.PartnerID=CP.PartnerID AND CF.FeatureCode=N'SALES' AND CF.IsEnabled=1 AND (CF.StartDate IS NULL OR CF.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (CF.ExpireDate IS NULL OR CF.ExpireDate>=CONVERT(date,SYSUTCDATETIME())) JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=CP.CompanyID AND C.PartnerID=CP.PartnerID AND C.IsActive=1
WHERE CP.ProjectID=@Core AND CP.IsEnabled=1
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()));

INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText)
SELECT PartnerID,CompanyID,@Trade,@Package,CASE WHEN IsTrial=1 THEN N'TRIAL' ELSE N'ACTIVE' END,StartDate,ExpireDate,1,N'ย้ายสิทธิ์เดิมจากระบบส่วนกลาง'
FROM #ExistingCompanies;
INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,StartDate,ExpireDate)
SELECT @Trade,PartnerID,CompanyID,1,IsTrial,StartDate,ExpireDate FROM #ExistingCompanies;
INSERT dbo.TDADCompanyFeature(ProjectID,PartnerID,CompanyID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate)
SELECT @Trade,PartnerID,CompanyID,N'SALES',1,IsTrial,StartDate,ExpireDate FROM #ExistingCompanies;
INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive)
SELECT UP.CompanyID,UP.UserID,@Trade,0,UP.IsActive
FROM dbo.TDADUserProject UP WHERE UP.ProjectID=@Core;

IF EXISTS(SELECT RoleGroupID,MenuCode,ActionCode,IsAllowed FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@Core AND MenuCode BETWEEN N'09001' AND N'09027'
          EXCEPT SELECT RoleGroupID,MenuCode,ActionCode,IsAllowed FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@Trade)
    THROW 53305, N'Stock role permissions were not preserved.', 1;
IF EXISTS(SELECT UP.CompanyID,UP.UserID,UP.IsActive FROM dbo.TDADUserProject UP JOIN #ExistingCompanies C ON C.CompanyID=UP.CompanyID WHERE UP.ProjectID=@Core
          EXCEPT SELECT CompanyID,UserID,IsActive FROM dbo.TDADUserProject WHERE ProjectID=@Trade)
    THROW 53306, N'Stock project membership was not preserved.', 1;

UPDATE dbo.TDADMainMenu SET FeatureCode=N'SALES',UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode=N'09' AND MenuCode BETWEEN N'09001' AND N'09027';
UPDATE dbo.TDADMenuGroup SET MenuGroupName=N'ระบบบริหารสต๊อก',UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'09';
UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME()
WHERE ProjectID=@Core AND MenuCode BETWEEN N'09001' AND N'09027';
