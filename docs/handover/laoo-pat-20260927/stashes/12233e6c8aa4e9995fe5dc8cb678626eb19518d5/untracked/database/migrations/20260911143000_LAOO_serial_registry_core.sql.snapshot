-- Serial registry is a Core inventory capability. The migration runner owns
-- the transaction, application lock, checksum and migration ledger.
SET XACT_ABORT ON;

DECLARE @CoreProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO' AND IsActive = 1
);

IF @CoreProjectID IS NULL
    THROW 52720, N'Active Core project LAOO is required.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADMainMenu
    WHERE MenuCode = N'08006' AND ScreenType = 1 AND IsActive = 1
)
    THROW 52721, N'Active ScreenType 1 menu 08006 is required.', 1;

UPDATE dbo.TDADProjectMenuGroup
SET IsActive = 1
WHERE ProjectID = @CoreProjectID AND MenuGroupCode = N'08';

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADProjectMenuGroup
    WHERE ProjectID = @CoreProjectID AND MenuGroupCode = N'08'
)
    INSERT dbo.TDADProjectMenuGroup(ProjectID, MenuGroupCode, SortOrder, IsActive)
    VALUES(@CoreProjectID, N'08', 1, 1);

UPDATE dbo.TDADProjectMenu
SET MenuGroupCode = N'08', SortOrder = 6, IsActive = 1
WHERE ProjectID = @CoreProjectID AND MenuCode = N'08006';

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADProjectMenu
    WHERE ProjectID = @CoreProjectID AND MenuCode = N'08006'
)
    INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive)
    VALUES(@CoreProjectID, N'08006', N'08', 6, 1);

UPDATE dbo.TDADProjectMenu
SET IsActive = 0
WHERE MenuCode = N'08006' AND ProjectID <> @CoreProjectID;

UPDATE dbo.TDADPermission
SET ScreenNameTH = N'ทะเบียน SN/อุปกรณ์',
    ScreenNameEN = N'Serial Registry',
    IsActive = 1
WHERE ProjectID = @CoreProjectID
  AND ScreenCode = N'08006'
  AND ActionCode IN (N'VIEW', N'EDIT');

INSERT dbo.TDADPermission
(
    ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
    ActionCode, ActionNameTH, IsActive
)
SELECT @CoreProjectID, N'08006', N'ทะเบียน SN/อุปกรณ์', N'Serial Registry',
       A.ActionCode, A.ActionNameTH, 1
FROM (VALUES (N'VIEW', N'แสดง'), (N'EDIT', N'แก้ไข')) A(ActionCode, ActionNameTH)
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADPermission P
    WHERE P.ProjectID = @CoreProjectID
      AND P.ScreenCode = N'08006'
      AND P.ActionCode = A.ActionCode
);

UPDATE dbo.TDADPermission
SET IsActive = 0
WHERE ScreenCode = N'08006' AND ProjectID <> @CoreProjectID;
