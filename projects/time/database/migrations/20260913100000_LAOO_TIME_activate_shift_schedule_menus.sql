-- Approved activation of Time shift and employee-schedule menus.
-- The menu, route, ScreenType and permission definitions were created by
-- 20260911200000_LAOO_TIME_shift_schedule.sql; this migration only exposes them.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint =
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_TIME' AND IsActive = 1);

    IF @ProjectID IS NULL
        THROW 52410, N'Active LAOO_TIME project is required to activate shift schedule menus.', 1;

    UPDATE dbo.TDADMenuGroup
    SET IsActive = 1,
        UpdateDate = SYSDATETIME()
    WHERE MenuGroupCode = N'27';

    UPDATE dbo.TDADProjectMenuGroup
    SET IsActive = 1,
        UpdateDate = SYSDATETIME()
    WHERE ProjectID = @ProjectID
      AND MenuGroupCode = N'27';

    UPDATE dbo.TDADMainMenu
    SET IsActive = 1,
        IsVisible = 1,
        UpdateDate = SYSDATETIME()
    WHERE MenuCode IN (N'27001', N'27002', N'27003', N'27004');

    UPDATE dbo.TDADProjectMenu
    SET IsActive = 1,
        UpdateDate = SYSDATETIME()
    WHERE ProjectID = @ProjectID
      AND MenuCode IN (N'27001', N'27002', N'27003', N'27004');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
