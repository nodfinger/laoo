SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_EVALUATION' AND IsActive = 1);
IF @ProjectID IS NULL THROW 53112, N'Active LAOO_EVALUATION project is required.', 1;

UPDATE dbo.TDADMainMenu
SET ScreenType = 2, IsVisible = 1, IsActive = 1, UpdateDate = SYSUTCDATETIME()
WHERE MenuCode = N'47001' AND RouteName = N'evaluationSettings' AND RoutePath = N'/company/evaluation-settings';
IF @@ROWCOUNT <> 1 THROW 53113, N'Evaluation settings menu 47001 was not found with the expected route.', 1;

UPDATE dbo.TDADProjectMenu
SET IsActive = 1, UpdateDate = SYSUTCDATETIME()
WHERE ProjectID = @ProjectID AND MenuCode = N'47001';
IF @@ROWCOUNT <> 1 THROW 53114, N'Evaluation project menu 47001 was not found.', 1;

UPDATE dbo.TDADPermission
SET IsActive = CASE WHEN ActionCode IN (N'VIEW', N'EDIT') THEN 1 ELSE 0 END,
    ModifiedDate = SYSUTCDATETIME()
WHERE ProjectID = @ProjectID AND ScreenCode = N'47001';

IF NOT EXISTS (SELECT 1 FROM dbo.TDADPermission WHERE ProjectID = @ProjectID AND ScreenCode = N'47001' AND ActionCode = N'VIEW' AND IsActive = 1)
    THROW 53115, N'Active VIEW permission for evaluation settings is required.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADPermission WHERE ProjectID = @ProjectID AND ScreenCode = N'47001' AND ActionCode = N'EDIT' AND IsActive = 1)
    THROW 53116, N'Active EDIT permission for evaluation settings is required.', 1;

COMMIT TRANSACTION;
