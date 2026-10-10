-- Test access only: DEMO company and c111; no other company is changed.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @run nvarchar(40)=N'PT_20261010_DEMO';
DECLARE @today date=CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
DECLARE @company bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PET' AND IsActive=1);
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@company AND Username=N'c111' AND IsActive=1);
IF @company IS NULL OR @partner IS NULL OR @project IS NULL OR @package IS NULL OR @actor IS NULL
 THROW 62200,N'Pet DEMO access prerequisites are missing',1;
IF EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription
 WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1
 AND ISNULL(ReasonText,N'')<>@run)
 THROW 62201,N'Another current Pet subscription exists; do not overwrite it',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription
 WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1)
BEGIN
 DECLARE @subscription bigint;
 INSERT dbo.TDADCompanyProjectSubscription(
  PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,
  IsCurrent,ReasonText,CreateBy)
 VALUES(@partner,@company,@project,@package,N'TRIAL',@today,
  DATEADD(day,30,@today),1,@run,@actor);
 SET @subscription=SCOPE_IDENTITY();
 INSERT dbo.TDADCompanyProjectSubscriptionAudit(
  SubscriptionID,PartnerID,CompanyID,ProjectID,PackageID,ActionCode,
  BeforeJson,AfterJson,ReasonText,ActorType,ActorID)
 VALUES(@subscription,@partner,@company,@project,@package,N'ASSIGN',NULL,
  CONCAT(N'{"runId":"',@run,N'","status":"TRIAL"}'),@run,N'TEST_FIXTURE',@actor);
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject
 WHERE CompanyID=@company AND ProjectID=@project)
 INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,
  IsTrial,StartDate,ExpireDate,CreatedBy)
 VALUES(@partner,@company,@project,1,1,@today,DATEADD(day,30,@today),@actor);
INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,
 IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
SELECT @partner,@company,@project,F.FeatureCode,1,1,@today,
 DATEADD(day,30,@today),@actor
FROM dbo.TDADProjectPackageFeature F
WHERE F.PackageID=@package AND F.IsEnabled=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyFeature C
 WHERE C.CompanyID=@company AND C.ProjectID=@project
 AND C.FeatureCode=F.FeatureCode);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject
 WHERE CompanyID=@company AND UserID=@actor AND ProjectID=@project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,
  IsActive,CreateDate,CreateBy)
 VALUES(@company,@actor,@project,0,1,SYSUTCDATETIME(),@actor);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,
 IsActive,Remark,CreatedBy)
SELECT @actor,@project,P.PermissionID,1,1,@run,@actor
FROM dbo.TDADPermission P
WHERE P.ProjectID=@project AND P.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U
 WHERE U.UserID=@actor AND U.ProjectID=@project
 AND U.PermissionID=P.PermissionID);
-- The member ownership rule for 62009 is still pending; keep it hidden.
UPDATE dbo.TDADMainMenu SET IsVisible=1
WHERE MenuCode IN(N'62001',N'62002',N'62003',N'62004',N'62005',
 N'62006',N'62007',N'62008',N'62010')
AND IsActive=1 AND IsVisible=0;
COMMIT;
