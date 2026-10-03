SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADProjectPackage',N'U') IS NULL
   OR OBJECT_ID(N'dbo.TDADCompanyProjectSubscription',N'U') IS NULL
    THROW 57230,N'Project package schema is required before LAOO_SCHOOL package backfill.',1;

BEGIN TRY
 BEGIN TRANSACTION;

 DECLARE @ProjectID bigint=(
  SELECT ProjectID FROM dbo.TDADProject
  WHERE ProjectCode=N'LAOO_SCHOOL' AND IsActive=1
 );
 IF @ProjectID IS NULL THROW 57231,N'LAOO_SCHOOL project is missing.',1;

 DECLARE @Packages TABLE(
  TierCode nvarchar(30),
  PackageCode nvarchar(50),
  PackageNameTH nvarchar(200),
  BillingCycle nvarchar(20),
  SortOrder int
 );
 INSERT @Packages VALUES
  (N'FREE',N'FREE',N'ฟรี',N'NONE',10),
  (N'STANDARD',N'STANDARD',N'มาตรฐาน',N'MONTHLY',20),
  (N'ENTERPRISE',N'ENTERPRISE',N'องค์กร',N'YEARLY',30);

 INSERT dbo.TDADProjectPackage(
  ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive
 )
 SELECT @ProjectID,P.PackageCode,P.PackageNameTH,P.TierCode,P.BillingCycle,P.SortOrder,1
 FROM @Packages P
 WHERE NOT EXISTS(
  SELECT 1 FROM dbo.TDADProjectPackage X
  WHERE X.ProjectID=@ProjectID AND X.PackageCode=P.PackageCode
 );

 INSERT dbo.TDADProjectPackageQuota(
  PackageID,QuotaCode,QuotaNameTH,LimitValue,UnitCode
 )
 SELECT PK.PackageID,Q.QuotaCode,Q.QuotaNameTH,
        CASE PK.TierCode
         WHEN N'FREE' THEN Q.FreeLimit
         WHEN N'STANDARD' THEN Q.StandardLimit
         ELSE Q.EnterpriseLimit
        END,
        Q.UnitCode
 FROM dbo.TDADProjectPackage PK
 CROSS APPLY(VALUES
  (N'MAX_USERS',N'จำนวนผู้ใช้',CAST(5 AS decimal(18,2)),CAST(25 AS decimal(18,2)),CAST(-1 AS decimal(18,2)),N'USER'),
  (N'MAX_BRANCHES',N'จำนวนสาขา',CAST(1 AS decimal(18,2)),CAST(3 AS decimal(18,2)),CAST(-1 AS decimal(18,2)),N'BRANCH'),
  (N'STORAGE_MB',N'พื้นที่จัดเก็บไฟล์',CAST(1024 AS decimal(18,2)),CAST(5120 AS decimal(18,2)),CAST(51200 AS decimal(18,2)),N'MB')
 ) Q(QuotaCode,QuotaNameTH,FreeLimit,StandardLimit,EnterpriseLimit,UnitCode)
 WHERE PK.ProjectID=@ProjectID
   AND NOT EXISTS(
    SELECT 1 FROM dbo.TDADProjectPackageQuota X
    WHERE X.PackageID=PK.PackageID AND X.QuotaCode=Q.QuotaCode
   );

 INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
 SELECT DISTINCT PK.PackageID,M.FeatureCode,1
 FROM dbo.TDADProjectPackage PK
 JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=PK.ProjectID AND PM.IsActive=1
 JOIN dbo.TDADMainMenu M
   ON M.MenuCode=PM.MenuCode
  AND M.IsActive=1
  AND M.FeatureCode IS NOT NULL
 WHERE PK.ProjectID=@ProjectID
   AND PK.TierCode IN(N'STANDARD',N'ENTERPRISE')
   AND NOT EXISTS(
    SELECT 1 FROM dbo.TDADProjectPackageFeature X
    WHERE X.PackageID=PK.PackageID AND X.FeatureCode=M.FeatureCode
   );

 INSERT dbo.TDADCompanyProjectSubscription(
  PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,
  IsCurrent,ReasonText,CreateDate,CreateBy
 )
 SELECT CP.PartnerID,CP.CompanyID,CP.ProjectID,PK.PackageID,
        CASE
         WHEN CP.IsEnabled=0 THEN N'SUSPENDED'
         WHEN CP.IsTrial=1 THEN N'TRIAL'
         ELSE N'ACTIVE'
        END,
        COALESCE(CP.StartDate,CONVERT(date,CP.CreateDate),CONVERT(date,SYSUTCDATETIME())),
        CP.ExpireDate,1,N'Migrated from TDADCompanyProject',SYSUTCDATETIME(),CP.CreatedBy
 FROM dbo.TDADCompanyProject CP
 JOIN dbo.TDADProjectPackage PK
   ON PK.ProjectID=CP.ProjectID
  AND PK.PackageCode=N'STANDARD'
  AND PK.IsActive=1
 WHERE CP.ProjectID=@ProjectID
   AND NOT EXISTS(
    SELECT 1 FROM dbo.TDADCompanyProjectSubscription S
    WHERE S.CompanyID=CP.CompanyID
      AND S.ProjectID=CP.ProjectID
      AND S.IsCurrent=1
   );

 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
