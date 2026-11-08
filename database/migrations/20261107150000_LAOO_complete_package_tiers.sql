/* Add missing package options without changing existing packages or subscriptions. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (
    SELECT 1 FROM dbo.TDADProject P
    WHERE P.IsActive=1 AND P.ProjectType<>N'CORE'
      AND NOT EXISTS (SELECT 1 FROM dbo.TDADProjectPackage S
                      WHERE S.ProjectID=P.ProjectID AND S.IsActive=1 AND S.TierCode=N'STANDARD')
)
    THROW 53500, N'Every active business project needs an active standard package.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.TDADProject P
    CROSS JOIN (VALUES(N'FREE'),(N'STANDARD'),(N'ENTERPRISE')) T(Code)
    JOIN dbo.TDADProjectPackage PK ON PK.ProjectID=P.ProjectID AND PK.PackageCode=T.Code
    WHERE P.IsActive=1 AND P.ProjectType<>N'CORE'
      AND NOT EXISTS (SELECT 1 FROM dbo.TDADProjectPackage E WHERE E.ProjectID=P.ProjectID AND E.TierCode=T.Code AND E.IsActive=1)
)
    THROW 53501, N'An inactive or conflicting package code requires review.', 1;

DECLARE @Added TABLE (PackageID bigint NOT NULL, ProjectID bigint NOT NULL);
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive)
OUTPUT inserted.PackageID,inserted.ProjectID INTO @Added(PackageID,ProjectID)
SELECT P.ProjectID,T.Code,T.NameTH,T.NameEN,T.Code,T.Cycle,0,N'THB',0,T.SortOrder,1
FROM dbo.TDADProject P
CROSS JOIN (VALUES
    (N'FREE',N'ฟรี',N'Free',N'NONE',0),
    (N'STANDARD',N'มาตรฐาน',N'Standard',N'MONTHLY',10),
    (N'ENTERPRISE',N'องค์กร',N'Enterprise',N'MONTHLY',20)
) T(Code,NameTH,NameEN,Cycle,SortOrder)
WHERE P.IsActive=1 AND P.ProjectType<>N'CORE'
  AND NOT EXISTS (SELECT 1 FROM dbo.TDADProjectPackage E WHERE E.ProjectID=P.ProjectID AND E.TierCode=T.Code AND E.IsActive=1);

INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
SELECT A.PackageID,F.FeatureCode,F.IsEnabled
FROM @Added A
CROSS APPLY (SELECT TOP (1) PackageID FROM dbo.TDADProjectPackage S
             WHERE S.ProjectID=A.ProjectID AND S.TierCode=N'STANDARD' AND S.IsActive=1
             ORDER BY S.PackageID) S
JOIN dbo.TDADProjectPackageFeature F ON F.PackageID=S.PackageID;

INSERT dbo.TDADProjectPackageQuota(PackageID,QuotaCode,QuotaNameTH,LimitValue,UnitCode)
SELECT A.PackageID,Q.QuotaCode,Q.QuotaNameTH,Q.LimitValue,Q.UnitCode
FROM @Added A
CROSS APPLY (SELECT TOP (1) PackageID FROM dbo.TDADProjectPackage S
             WHERE S.ProjectID=A.ProjectID AND S.TierCode=N'STANDARD' AND S.IsActive=1
             ORDER BY S.PackageID) S
JOIN dbo.TDADProjectPackageQuota Q ON Q.PackageID=S.PackageID;
