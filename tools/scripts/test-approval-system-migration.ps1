$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open()
$tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand(); $q.Transaction = $tx
    $q.CommandText = [IO.File]::ReadAllText((Join-Path $root 'database/migrations/20261111190000_LAOO_approval_system.sql'))
    [void]$q.ExecuteNonQuery()
    $q.CommandText = @'
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_APPROVAL');
IF @project IS NULL THROW 54201,N'Missing approval project',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@project AND MenuCode=N'10011' AND IsActive=1) THROW 54202,N'Existing menu not moved',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'68001' AND ScreenType=2 AND AllowPrint=0 AND AllowExport=0) THROW 54203,N'Incorrect settings menu',1;
IF EXISTS(SELECT RoleGroupID,MenuCode,ActionCode,IsAllowed FROM dbo.TDADRoleGroupPermission WHERE ProjectID=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO') AND MenuCode=N'10011' EXCEPT SELECT RoleGroupID,MenuCode,ActionCode,IsAllowed FROM dbo.TDADRoleGroupPermission WHERE ProjectID=@project AND MenuCode=N'10011') THROW 54204,N'Existing role grants not preserved',1;
IF EXISTS(SELECT PartnerID,CompanyID FROM dbo.TDADCompanyProject WHERE ProjectID=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO') AND IsEnabled=1 AND (StartDate IS NULL OR StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (ExpireDate IS NULL OR ExpireDate>=CONVERT(date,SYSUTCDATETIME())) EXCEPT SELECT PartnerID,CompanyID FROM dbo.TDADCompanyProjectSubscription WHERE ProjectID=@project AND IsCurrent=1 AND StatusCode=N'ACTIVE') THROW 54205,N'Existing enabled company lost access',1;
IF EXISTS(SELECT 1 FROM dbo.TDADProjectPackage P WHERE P.ProjectID=@project AND P.IsActive=1 AND NOT EXISTS (SELECT 1 FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=P.PackageID AND F.FeatureCode=N'APPROVAL_SYSTEM' AND F.IsEnabled=1)) THROW 54206,N'Package feature missing',1;
'@
    [void]$q.ExecuteNonQuery()
    Write-Output 'Approval project migration checks passed; rolled back.'
} finally { $tx.Rollback(); $db.Close() }
