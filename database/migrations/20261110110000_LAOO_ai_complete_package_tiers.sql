/* Add AI package tiers without altering existing company subscriptions. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_AI' AND IsActive=1);
IF @ProjectID IS NULL THROW 53900, N'Active AI project is required.', 1;
DECLARE @StandardID bigint = (SELECT TOP (1) PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@ProjectID AND TierCode=N'STANDARD' AND IsActive=1 ORDER BY PackageID);
IF @StandardID IS NULL THROW 53901, N'Active standard AI package is required.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADProjectPackage WHERE ProjectID=@ProjectID AND PackageCode IN (N'FREE',N'ENTERPRISE') AND IsActive=0)
    THROW 53902, N'Inactive AI package requires review.', 1;

DECLARE @Added TABLE (PackageID bigint NOT NULL);
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive)
OUTPUT inserted.PackageID INTO @Added(PackageID)
SELECT @ProjectID,T.Code,T.NameTH,T.NameEN,T.Code,T.Cycle,0,N'THB',0,T.SortOrder,1
FROM (VALUES (N'FREE',N'ฟรี',N'Free',N'NONE',0),
             (N'ENTERPRISE',N'องค์กร',N'Enterprise',N'MONTHLY',20)) T(Code,NameTH,NameEN,Cycle,SortOrder)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADProjectPackage P WHERE P.ProjectID=@ProjectID AND (P.TierCode=T.Code OR P.PackageCode=T.Code));

INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
SELECT A.PackageID,F.FeatureCode,F.IsEnabled FROM @Added A
JOIN dbo.TDADProjectPackageFeature F ON F.PackageID=@StandardID;
INSERT dbo.TDADProjectPackageQuota(PackageID,QuotaCode,QuotaNameTH,LimitValue,UnitCode)
SELECT A.PackageID,Q.QuotaCode,Q.QuotaNameTH,Q.LimitValue,Q.UnitCode FROM @Added A
JOIN dbo.TDADProjectPackageQuota Q ON Q.PackageID=@StandardID;
