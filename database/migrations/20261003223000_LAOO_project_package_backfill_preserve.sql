SET XACT_ABORT ON;
BEGIN TRANSACTION;

UPDATE S
SET S.PackageID=StandardPackage.PackageID,
    S.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_PROVIDER'
JOIN dbo.TDADProjectPackage CurrentPackage ON CurrentPackage.PackageID=S.PackageID AND CurrentPackage.PackageCode=N'FREE'
JOIN dbo.TDADProjectPackage StandardPackage ON StandardPackage.ProjectID=S.ProjectID AND StandardPackage.PackageCode=N'STANDARD' AND StandardPackage.IsActive=1
WHERE S.IsCurrent=1 AND S.ReasonText=N'Migrated from TDADCompanyProject';

COMMIT TRANSACTION;
