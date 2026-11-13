SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SourceProjectID bigint = (
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_MY' AND IsActive = 1
);
IF @SourceProjectID IS NULL
    THROW 54270, N'Active My System project is required to transfer SC Request.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode = N'69' AND IsActive = 1)
    THROW 54271, N'Purchasing menu group 69 is required.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.TDADMainMenu
    WHERE MenuCode = N'69002'
      AND ScreenType = 4
      AND RouteName = N'mySystemPurchaseScRequest'
      AND RoutePath = N'/company/my-system/purchase-sc-request'
      AND IsActive = 1
)
    THROW 54272, N'SC Request menu contract differs from the approved contract.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_PURCHASING')
BEGIN
    INSERT dbo.TDADProject(
        ProjectCode, ProjectNameTH, ProjectNameEN, DescriptionText, ProjectType,
        SortOrder, IconName, IsExpandedDefault, IsActive
    )
    VALUES(
        N'LAOO_PURCHASING', N'ระบบจัดซื้อ', N'Purchasing',
        N'Purchase request and purchasing workflow', N'BUSINESS',
        690, N'request_quote', 0, 1
    );
END;

DECLARE @PurchasingProjectID bigint = (
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_PURCHASING' AND IsActive = 1
);
IF @PurchasingProjectID IS NULL
    THROW 54273, N'Active purchasing project is required.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode = N'PURCHASING')
BEGIN
    INSERT dbo.TDADFeature(FeatureCode, FeatureName, FeatureDescription, IsActive, SortOrder)
    VALUES(N'PURCHASING', N'ระบบจัดซื้อ', N'Purchase request and purchasing workflow', 1, 690);
END;

UPDATE dbo.TDADMainMenu
SET FeatureCode = N'PURCHASING', UpdateDate = SYSUTCDATETIME()
WHERE MenuCode = N'69002';

IF NOT EXISTS (
    SELECT 1 FROM dbo.TDADProjectMenuGroup
    WHERE ProjectID = @PurchasingProjectID AND MenuGroupCode = N'69'
)
BEGIN
    INSERT dbo.TDADProjectMenuGroup(ProjectID, MenuGroupCode, SortOrder, IsActive)
    VALUES(@PurchasingProjectID, N'69', 1, 1);
END
ELSE
BEGIN
    UPDATE dbo.TDADProjectMenuGroup
    SET IsActive = 1, SortOrder = 1, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @PurchasingProjectID AND MenuGroupCode = N'69';
END;

UPDATE dbo.TDADProjectMenu
SET IsActive = 0, UpdateDate = SYSUTCDATETIME()
WHERE ProjectID = @SourceProjectID AND MenuCode = N'69002';

IF NOT EXISTS (
    SELECT 1 FROM dbo.TDADProjectMenu
    WHERE ProjectID = @PurchasingProjectID AND MenuCode = N'69002'
)
BEGIN
    INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive)
    VALUES(@PurchasingProjectID, N'69002', N'69', 20, 1);
END
ELSE
BEGIN
    UPDATE dbo.TDADProjectMenu
    SET MenuGroupCode = N'69', SortOrder = 20, IsActive = 1, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @PurchasingProjectID AND MenuCode = N'69002';
END;

DECLARE @Actions TABLE(
    ActionCode nvarchar(50) NOT NULL PRIMARY KEY,
    ActionNameTH nvarchar(200) NOT NULL,
    ActionNameEN nvarchar(200) NOT NULL
);
INSERT @Actions(ActionCode, ActionNameTH, ActionNameEN)
VALUES
    (N'VIEW', N'ดูข้อมูล', N'View'),
    (N'CREATE', N'เพิ่ม', N'Create'),
    (N'EDIT', N'แก้ไข', N'Edit'),
    (N'DELETE', N'ลบ', N'Delete'),
    (N'UPLOAD', N'แนบไฟล์', N'Upload');

INSERT dbo.TDADPermission(
    ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
    ActionCode, ActionNameTH, ActionNameEN, IsActive
)
SELECT @PurchasingProjectID, N'69002', N'SC Request', N'SC Request',
       a.ActionCode, a.ActionNameTH, a.ActionNameEN, 1
FROM @Actions a
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.TDADPermission p
    WHERE p.ProjectID = @PurchasingProjectID
      AND p.ScreenCode = N'69002'
      AND p.ActionCode = a.ActionCode
);

UPDATE dbo.TDADPermission
SET IsActive = 1
WHERE ProjectID = @PurchasingProjectID
  AND ScreenCode = N'69002'
  AND ActionCode IN (N'VIEW', N'CREATE', N'EDIT', N'DELETE', N'UPLOAD');

INSERT dbo.TDADRoleGroupPermission(RoleGroupID, ProjectID, MenuCode, ActionCode, IsAllowed, CreatedBy)
SELECT source.RoleGroupID, @PurchasingProjectID, N'69002', source.ActionCode,
       source.IsAllowed, N'purchasing-bootstrap'
FROM dbo.TDADRoleGroupPermission source
WHERE source.ProjectID = @SourceProjectID
  AND source.MenuCode = N'69002'
  AND source.ActionCode IN (N'VIEW', N'CREATE', N'EDIT', N'DELETE', N'UPLOAD')
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.TDADRoleGroupPermission target
      WHERE target.RoleGroupID = source.RoleGroupID
        AND target.ProjectID = @PurchasingProjectID
        AND target.MenuCode = N'69002'
        AND target.ActionCode = source.ActionCode
  );

INSERT dbo.TDADUserPermission(UserID, ProjectID, PermissionID, IsAllowed, IsActive, Remark)
SELECT source.UserID, @PurchasingProjectID, target.PermissionID,
       source.IsAllowed, source.IsActive, source.Remark
FROM dbo.TDADUserPermission source
JOIN dbo.TDADPermission sourcePermission
  ON sourcePermission.PermissionID = source.PermissionID
 AND sourcePermission.ProjectID = @SourceProjectID
JOIN dbo.TDADPermission target
  ON target.ProjectID = @PurchasingProjectID
 AND target.ScreenCode = sourcePermission.ScreenCode
 AND target.ActionCode = sourcePermission.ActionCode
WHERE source.ProjectID = @SourceProjectID
  AND sourcePermission.ScreenCode = N'69002'
  AND sourcePermission.ActionCode IN (N'VIEW', N'CREATE', N'EDIT', N'DELETE', N'UPLOAD')
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.TDADUserPermission existing
      WHERE existing.UserID = source.UserID
        AND existing.ProjectID = @PurchasingProjectID
        AND existing.PermissionID = target.PermissionID
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.TDADProjectPackage
    WHERE ProjectID = @PurchasingProjectID AND PackageCode = N'STANDARD'
)
BEGIN
    INSERT dbo.TDADProjectPackage(
        ProjectID, PackageCode, PackageNameTH, PackageNameEN, TierCode,
        BillingCycle, Price, CurrencyCode, TrialDays, SortOrder, IsActive
    )
    VALUES(
        @PurchasingProjectID, N'STANDARD', N'มาตรฐาน', N'Standard',
        N'STANDARD', N'MONTHLY', 0, N'THB', 0, 10, 1
    );
END;

DECLARE @PackageID bigint = (
    SELECT PackageID
    FROM dbo.TDADProjectPackage
    WHERE ProjectID = @PurchasingProjectID AND PackageCode = N'STANDARD' AND IsActive = 1
);
IF @PackageID IS NULL
    THROW 54274, N'Active purchasing package is required.', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.TDADProjectPackageFeature
    WHERE PackageID = @PackageID AND FeatureCode = N'PURCHASING'
)
BEGIN
    INSERT dbo.TDADProjectPackageFeature(PackageID, FeatureCode, IsEnabled)
    VALUES(@PackageID, N'PURCHASING', 1);
END;

INSERT dbo.TDADCompanyProjectSubscription(
    PartnerID, CompanyID, ProjectID, PackageID, StatusCode, StartDate,
    ExpireDate, IsCurrent, ReasonText
)
SELECT source.PartnerID, source.CompanyID, @PurchasingProjectID, @PackageID,
       N'ACTIVE', CONVERT(date, SYSUTCDATETIME()), source.ExpireDate, 1,
       N'Purchasing project bootstrap'
FROM dbo.TDADCompanyProject source
WHERE source.ProjectID = @SourceProjectID
  AND source.IsEnabled = 1
  AND (source.StartDate IS NULL OR source.StartDate <= CONVERT(date, SYSUTCDATETIME()))
  AND (source.ExpireDate IS NULL OR source.ExpireDate >= CONVERT(date, SYSUTCDATETIME()))
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.TDADCompanyProjectSubscription subscription
      WHERE subscription.ProjectID = @PurchasingProjectID
        AND subscription.PartnerID = source.PartnerID
        AND subscription.CompanyID = source.CompanyID
        AND subscription.IsCurrent = 1
  );

INSERT dbo.TDADCompanyProject(
    ProjectID, PartnerID, CompanyID, IsEnabled, IsTrial, StartDate, ExpireDate
)
SELECT @PurchasingProjectID, subscription.PartnerID, subscription.CompanyID,
       1, 0, subscription.StartDate, subscription.ExpireDate
FROM dbo.TDADCompanyProjectSubscription subscription
WHERE subscription.ProjectID = @PurchasingProjectID
  AND subscription.IsCurrent = 1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.TDADCompanyProject existing
      WHERE existing.ProjectID = @PurchasingProjectID
        AND existing.PartnerID = subscription.PartnerID
        AND existing.CompanyID = subscription.CompanyID
  );

INSERT dbo.TDADCompanyFeature(
    ProjectID, PartnerID, CompanyID, FeatureCode, IsEnabled, IsTrial, StartDate, ExpireDate
)
SELECT @PurchasingProjectID, company.PartnerID, company.CompanyID,
       N'PURCHASING', 1, 0, company.StartDate, company.ExpireDate
FROM dbo.TDADCompanyProject company
WHERE company.ProjectID = @PurchasingProjectID
  AND company.IsEnabled = 1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.TDADCompanyFeature feature
      WHERE feature.ProjectID = @PurchasingProjectID
        AND feature.PartnerID = company.PartnerID
        AND feature.CompanyID = company.CompanyID
        AND feature.FeatureCode = N'PURCHASING'
  );
