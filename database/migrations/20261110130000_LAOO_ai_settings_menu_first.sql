SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_AI' AND IsActive = 1);
IF @ProjectID IS NULL OR NOT EXISTS (
    SELECT 1 FROM dbo.TDADProjectMenu
    WHERE ProjectID = @ProjectID AND MenuCode = N'64002' AND MenuGroupCode = N'64' AND IsActive = 1
)
    THROW 53990, N'Active AI settings menu not found.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'64002' AND MenuGroupCode = N'64' AND ScreenType = 2)
    THROW 53991, N'AI settings menu metadata does not match.', 1;

DECLARE @FirstOrder int = (SELECT MIN(SortOrder) FROM dbo.TDADProjectMenu WHERE ProjectID = @ProjectID AND MenuGroupCode = N'64' AND IsActive = 1 AND MenuCode <> N'64002');
IF @FirstOrder IS NULL SET @FirstOrder = 1;
IF @FirstOrder <= -2147483648 THROW 53992, N'Cannot place AI settings before existing menu order.', 1;
SET @FirstOrder = @FirstOrder - 1;

UPDATE dbo.TDADProjectMenu SET SortOrder = @FirstOrder WHERE ProjectID = @ProjectID AND MenuCode = N'64002' AND MenuGroupCode = N'64';
UPDATE dbo.TDADMainMenu SET SortOrder = @FirstOrder WHERE MenuCode = N'64002';
