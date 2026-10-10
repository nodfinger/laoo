-- Rental acceptance fixture for DEMO only. Apply with Laoo.TestDataRunner.
-- Run ID marks the subscription, c111 permissions, and rental warehouses.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @run nvarchar(40)=N'RN_20261009_DEMO';
DECLARE @today date=CONVERT(date,SYSUTCDATETIME());
DECLARE @company bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_RENTAL' AND IsActive=1);
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@company AND Username=N'c111' AND IsActive=1);
DECLARE @home bigint=(SELECT BranchID FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchCode=N'HO' AND IsActive=1);
DECLARE @p110 bigint=(SELECT BranchID FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchCode=N'P110' AND IsActive=1);
IF @company IS NULL OR @partner IS NULL OR @project IS NULL OR @package IS NULL OR @actor IS NULL OR @home IS NULL OR @p110 IS NULL
 THROW 60601,N'Rental DEMO prerequisites are missing.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1 AND ReasonText<>@run)
 THROW 60602,N'Another current Rental subscription exists; do not overwrite it.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1)
BEGIN
 DECLARE @subscription bigint;
 INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText,CreateBy)
 VALUES(@partner,@company,@project,@package,N'TRIAL',@today,DATEADD(day,30,@today),1,@run,@actor);
 SET @subscription=SCOPE_IDENTITY();
 INSERT dbo.TDADCompanyProjectSubscriptionAudit(SubscriptionID,PartnerID,CompanyID,ProjectID,PackageID,ActionCode,BeforeJson,AfterJson,ReasonText,ActorType,ActorID)
 VALUES(@subscription,@partner,@company,@project,@package,N'ASSIGN',NULL,CONCAT(N'{"runId":"',@run,N'","status":"TRIAL"}'),@run,N'TEST_FIXTURE',@actor);
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@company AND ProjectID=@project)
 INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 VALUES(@partner,@company,@project,1,1,@today,DATEADD(day,30,@today),@actor);
INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
SELECT @partner,@company,@project,F.FeatureCode,1,1,@today,DATEADD(day,30,@today),@actor
FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=@package AND F.IsEnabled=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyFeature C WHERE C.CompanyID=@company AND C.ProjectID=@project AND C.FeatureCode=F.FeatureCode);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@company AND UserID=@actor AND ProjectID=@project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
 VALUES(@company,@actor,@project,0,1,SYSUTCDATETIME(),@actor);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @actor,@project,P.PermissionID,1,1,@run,@actor
FROM dbo.TDADPermission P WHERE P.ProjectID=@project AND P.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U WHERE U.UserID=@actor AND U.ProjectID=@project AND U.PermissionID=P.PermissionID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVWarehouse WHERE CompanyID=@company AND WarehouseCode=N'RENTAL-RN261009-HO')
 INSERT dbo.TDIVWarehouse(CompanyID,BranchID,WarehouseCode,WarehouseName,IsDefault,IsActive,CreatedBy)
 VALUES(@company,@home,N'RENTAL-RN261009-HO',N'คลังเช่าทดสอบสำนักงานใหญ่ [RN_20261009_DEMO]',0,1,@actor);
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVWarehouse WHERE CompanyID=@company AND WarehouseCode=N'RENTAL-RN261009-P110')
 INSERT dbo.TDIVWarehouse(CompanyID,BranchID,WarehouseCode,WarehouseName,IsDefault,IsActive,CreatedBy)
 VALUES(@company,@p110,N'RENTAL-RN261009-P110',N'คลังเช่าทดสอบเพชรเกษม [RN_20261009_DEMO]',0,1,@actor);
-- Routes and server guards exist; only companies with an entitlement see these menus.
UPDATE dbo.TDADMainMenu SET IsVisible=1 WHERE MenuCode BETWEEN N'60001' AND N'60010' AND IsVisible=0;
