/* Move OCR menus to a package-controlled Business Project; no company is subscribed. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Core bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @Core IS NULL THROW 53210, N'Active core Project is required.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_OCR')
    THROW 53211, N'LAOO_OCR already exists; review existing configuration.', 1;
IF (SELECT COUNT(*) FROM dbo.TDADMainMenu WHERE MenuCode IN(N'55001',N'55002') AND MenuGroupCode=N'55' AND IsActive=1 AND ((MenuCode=N'55001' AND ScreenType=2) OR (MenuCode=N'55002' AND ScreenType=1)))<>2
    THROW 53212, N'OCR menus differ from the expected configuration.', 1;

INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,ProjectType,SortOrder,IconName,IsExpandedDefault,IsActive)
VALUES(N'LAOO_OCR',N'ระบบ OCR นามบัตร',N'Business Card OCR',N'อ่านนามบัตรและจัดการผู้ติดต่อ',N'BUSINESS',550,N'document_scanner',0,1);
DECLARE @Ocr bigint=SCOPE_IDENTITY();

IF NOT EXISTS(SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'BUSINESS_CARD_OCR')
    INSERT dbo.TDADFeature(FeatureCode,FeatureName,FeatureDescription,IsActive,SortOrder)
    VALUES(N'BUSINESS_CARD_OCR',N'OCR นามบัตร',N'อ่านนามบัตรและจัดการผู้ติดต่อ',1,550);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'BUSINESS_CARD_OCR' AND IsActive=1)
    THROW 53213, N'OCR feature exists but is inactive.', 1;

UPDATE dbo.TDADMainMenu SET FeatureCode=N'BUSINESS_CARD_OCR',UpdateDate=SYSUTCDATETIME() WHERE MenuCode IN(N'55001',N'55002');
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive)
VALUES(@Ocr,N'55',1,1);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT @Ocr,MenuCode,MenuGroupCode,SortOrder,1 FROM dbo.TDADMainMenu WHERE MenuCode IN(N'55001',N'55002');

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @Ocr,P.ScreenCode,P.ScreenNameTH,P.ScreenNameEN,P.ActionCode,P.ActionNameTH,P.ActionNameEN,P.IsActive
FROM dbo.TDADPermission P WHERE P.ProjectID=@Core AND P.ScreenCode IN(N'55001',N'55002');

INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT RP.RoleGroupID,@Ocr,RP.MenuCode,RP.ActionCode,RP.IsAllowed,N'ocr-project-migration'
FROM dbo.TDADRoleGroupPermission RP WHERE RP.ProjectID=@Core AND RP.MenuCode IN(N'55001',N'55002');

INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT UP.UserID,@Ocr,NP.PermissionID,UP.IsAllowed,UP.IsActive,UP.Remark
FROM dbo.TDADUserPermission UP
JOIN dbo.TDADPermission OP ON OP.PermissionID=UP.PermissionID AND OP.ProjectID=@Core
JOIN dbo.TDADPermission NP ON NP.ProjectID=@Ocr AND NP.ScreenCode=OP.ScreenCode AND NP.ActionCode=OP.ActionCode
WHERE UP.ProjectID=@Core AND OP.ScreenCode IN(N'55001',N'55002');

/* Preserve project membership only for people with an existing OCR grant; subscription remains required. */
INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive)
SELECT DISTINCT U.CompanyID,U.UserID,@Ocr,0,1
FROM dbo.TDADUser U
WHERE U.IsActive=1 AND U.CompanyID IS NOT NULL AND (
 EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP WHERE UP.UserID=U.UserID AND UP.ProjectID=@Ocr AND UP.IsActive=1 AND UP.IsAllowed=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE
    JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=U.CompanyID AND E.IsActive=1
    JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=E.EmployeeID AND ERG.IsActive=1
    JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.CompanyID=U.CompanyID AND RG.IsActive=1
    JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@Ocr AND RP.IsAllowed=1
    WHERE UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID AND UE.IsActive=1));

INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive)
VALUES(@Ocr,N'STANDARD',N'มาตรฐาน',N'Standard',N'STANDARD',N'MONTHLY',0,N'THB',0,10,1);
DECLARE @Package bigint=SCOPE_IDENTITY();
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled) VALUES(@Package,N'BUSINESS_CARD_OCR',1);

UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME()
WHERE ProjectID=@Core AND MenuCode IN(N'55001',N'55002');
COMMIT TRANSACTION;
