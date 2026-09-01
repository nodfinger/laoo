SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @TargetMenus TABLE (MenuCode nvarchar(40) PRIMARY KEY);
    INSERT INTO @TargetMenus (MenuCode) VALUES (N'06003'), (N'13001');

    DECLARE @PermissionIDs TABLE (PermissionID bigint PRIMARY KEY);
    INSERT INTO @PermissionIDs (PermissionID)
    SELECT PermissionID
    FROM dbo.TDADPermission
    WHERE ScreenCode IN (SELECT MenuCode FROM @TargetMenus);

    DECLARE
        @DeletedRolePermissions int = 0,
        @DeletedPermissions int = 0,
        @DeletedMenus int = 0,
        @DeletedGroups int = 0,
        @DeletedFeatures int = 0,
        @DeletedCompanyFeatures int = 0,
        @DeletedFeatureHistory int = 0;

    DELETE FROM dbo.TDADRoleGroupPermission
    WHERE MenuCode IN (SELECT MenuCode FROM @TargetMenus);
    SET @DeletedRolePermissions = @@ROWCOUNT;

    DELETE FROM dbo.TDADUserFavorite
    WHERE MenuCode IN (SELECT MenuCode FROM @TargetMenus);

    DELETE FROM dbo.TDADUserPermissionPoint
    WHERE MenuCode IN (SELECT MenuCode FROM @TargetMenus);

    DELETE FROM dbo.TDADUserPermissionPointName
    WHERE MenuCode IN (SELECT MenuCode FROM @TargetMenus);

    DELETE FROM dbo.TDADPermissionTemplateDetail
    WHERE PermissionID IN (SELECT PermissionID FROM @PermissionIDs);

    DELETE FROM dbo.TDADUserPermission
    WHERE PermissionID IN (SELECT PermissionID FROM @PermissionIDs);

    DELETE FROM dbo.TDADPartnerUserPermission
    WHERE PermissionID IN (SELECT PermissionID FROM @PermissionIDs);

    DELETE FROM dbo.TDADLaooUserPermission
    WHERE PermissionID IN (SELECT PermissionID FROM @PermissionIDs);

    DELETE FROM dbo.TDADPermission
    WHERE PermissionID IN (SELECT PermissionID FROM @PermissionIDs);
    SET @DeletedPermissions = @@ROWCOUNT;

    DELETE H
    FROM dbo.TDADCompanyFeatureHistory H
    INNER JOIN dbo.TDADCompanyFeature C
        ON C.CompanyFeatureID = H.CompanyFeatureID
    WHERE C.FeatureCode = N'SALES_MANAGEMENT';
    SET @DeletedFeatureHistory = @@ROWCOUNT;

    DELETE FROM dbo.TDADCompanyFeature
    WHERE FeatureCode = N'SALES_MANAGEMENT';
    SET @DeletedCompanyFeatures = @@ROWCOUNT;

    DELETE FROM dbo.TDADFeature
    WHERE FeatureCode = N'SALES_MANAGEMENT';
    SET @DeletedFeatures = @@ROWCOUNT;

    DELETE FROM dbo.TDADMainMenu
    WHERE MenuCode IN (SELECT MenuCode FROM @TargetMenus);
    SET @DeletedMenus = @@ROWCOUNT;

    DELETE FROM dbo.TDADMenuGroup
    WHERE MenuGroupCode = N'13'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.TDADMainMenu
          WHERE MenuGroupCode = N'13'
      );
    SET @DeletedGroups = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT
        @DeletedRolePermissions AS DeletedRolePermissions,
        @DeletedPermissions AS DeletedPermissions,
        @DeletedFeatureHistory AS DeletedFeatureHistory,
        @DeletedCompanyFeatures AS DeletedCompanyFeatures,
        @DeletedFeatures AS DeletedFeatures,
        @DeletedMenus AS DeletedMenus,
        @DeletedGroups AS DeletedGroups;

    SELECT
        (SELECT COUNT(*) FROM dbo.TDADMainMenu WHERE MenuCode IN (N'06003',N'13001')) AS RemainingMenus,
        (SELECT COUNT(*) FROM dbo.TDADMenuGroup WHERE MenuGroupCode = N'13') AS RemainingGroup13,
        (SELECT COUNT(*) FROM dbo.TDADFeature WHERE FeatureCode = N'SALES_MANAGEMENT') AS RemainingFeatures,
        (SELECT COUNT(*) FROM dbo.TDADCompanyFeature WHERE FeatureCode = N'SALES_MANAGEMENT') AS RemainingCompanyFeatures,
        (SELECT COUNT(*) FROM dbo.TDADRoleGroupPermission WHERE MenuCode IN (N'06003',N'13001')) AS RemainingRolePermissions;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
