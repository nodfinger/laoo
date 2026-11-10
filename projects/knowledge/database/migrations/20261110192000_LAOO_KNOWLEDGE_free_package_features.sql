SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Install missing feature rows only; keep explicitly disabled features untouched.
INSERT dbo.TDADProjectPackageFeature(PackageID, FeatureCode, IsEnabled)
SELECT PK.PackageID, M.FeatureCode, 1
FROM dbo.TDADProject P
JOIN dbo.TDADProjectPackage PK ON PK.ProjectID=P.ProjectID AND PK.PackageCode=N'FREE' AND PK.IsActive=1
JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID AND PM.IsActive=1
JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1
WHERE P.ProjectCode=N'LAOO_KNOWLEDGE' AND P.IsActive=1
 AND M.MenuCode IN (N'49001',N'49002',N'49003',N'49004',N'49005',N'49006',N'49007',N'49008')
 AND NOT EXISTS (SELECT 1 FROM dbo.TDADProjectPackageFeature PF WITH (UPDLOCK,HOLDLOCK)
                 WHERE PF.PackageID=PK.PackageID AND PF.FeatureCode=M.FeatureCode);
