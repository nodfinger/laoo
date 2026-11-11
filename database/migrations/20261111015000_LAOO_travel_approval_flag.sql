SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDADMainMenu', N'AllowDataAccessSettings') IS NULL
   OR COL_LENGTH(N'dbo.TDADMainMenu', N'RequiresApproval') IS NULL
    THROW 51000, 'Required menu access and approval columns are missing.', 1;

IF (SELECT COUNT(*) FROM dbo.TDADMainMenu WHERE MenuCode IN (N'20001', N'21001', N'66001')) <> 3
    THROW 51001, 'Expected service, meeting and travel menus were not found uniquely.', 1;

UPDATE dbo.TDADMainMenu SET AllowDataAccessSettings = 1
WHERE MenuCode IN (N'20001', N'21001', N'66001');

UPDATE dbo.TDADMainMenu SET RequiresApproval = 1
WHERE MenuCode = N'66001';

IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode IN (N'20001', N'21001', N'66001') AND AllowDataAccessSettings <> 1)
   OR EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'66001' AND RequiresApproval <> 1)
    THROW 51002, 'Menu flags could not be verified.', 1;
