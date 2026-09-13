-- Shared physical location master: Core owns Building/Floor/Room.
SET XACT_ABORT ON;

DECLARE @CoreProjectID bigint =
(
    SELECT TOP (1) ProjectID FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO' AND IsActive = 1
);
DECLARE @ServiceProjectID bigint =
(
    SELECT TOP (1) ProjectID FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_SERVICE' AND IsActive = 1
);

IF @CoreProjectID IS NULL
    THROW 52900, N'Active Core project LAOO is required.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.TDADMainMenu
    WHERE MenuCode = N'14001'
      AND ScreenType = 1
      AND RouteName = N'assetLocations'
      AND RoutePath = N'/asset/locations'
)
    THROW 52901, N'Menu 14001 conflicts with the shared location master contract.', 1;

UPDATE dbo.TDADMainMenu
SET MenuName = N'ผังสถานที่และพื้นที่',
    IsActive = 1,
    IsVisible = 1,
    UpdateDate = SYSUTCDATETIME()
WHERE MenuCode = N'14001';

UPDATE dbo.TDADProjectMenu
SET MenuGroupCode = N'14', SortOrder = 10, IsActive = 1, UpdateDate = SYSUTCDATETIME()
WHERE ProjectID = @CoreProjectID AND MenuCode = N'14001';

IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID = @CoreProjectID AND MenuCode = N'14001')
    INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive, CreateDate)
    VALUES(@CoreProjectID, N'14001', N'14', 10, 1, SYSUTCDATETIME());

IF @ServiceProjectID IS NOT NULL
    UPDATE dbo.TDADProjectMenu
    SET IsActive = 0, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @ServiceProjectID AND MenuCode = N'14001';