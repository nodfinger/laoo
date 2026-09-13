/* Keep the Service Person registry under the existing Service entitlement. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ServiceProjectID bigint =
    (
        SELECT TOP (1) ProjectID
        FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO_SERVICE' AND IsActive=1
    );
    IF @ServiceProjectID IS NULL
        THROW 52960, N'Active LAOO_SERVICE project is required.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADFeature
        WHERE FeatureCode=N'SERVICE' AND IsActive=1
    )
        THROW 52961, N'Active SERVICE feature is required.', 1;

    UPDATE dbo.TDADMainMenu
    SET FeatureCode=N'SERVICE', UpdateDate=SYSUTCDATETIME()
    WHERE MenuCode=N'14004'
      AND RouteName=N'servicePersons'
      AND RoutePath=N'/service/persons';

    IF @@ROWCOUNT<>1
        THROW 52962, N'Service Person menu 14004 was not found or has an unexpected route.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;