/* Inventory catalog and serial registry are read-only; work-order issue is a document. */
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF (SELECT COUNT(*) FROM dbo.TDADMainMenu
        WHERE (MenuCode = N'08002' AND RouteName = N'inventoryItems')
           OR (MenuCode = N'08003' AND RouteName = N'inventoryUsage')
           OR (MenuCode = N'08006' AND RouteName = N'itemInstances')) <> 3
        THROW 52008, 'Inventory menu metadata is missing or has a different route.', 1;

    UPDATE dbo.TDADMainMenu
       SET ScreenType = CASE WHEN MenuCode = N'08003' THEN 4 ELSE 3 END,
           UpdateDate = SYSUTCDATETIME()
     WHERE MenuCode IN (N'08002', N'08003', N'08006')
       AND ScreenType <> CASE WHEN MenuCode = N'08003' THEN 4 ELSE 3 END;

    UPDATE dbo.TDADPermission
       SET IsActive = 0,
           ModifiedDate = SYSUTCDATETIME()
     WHERE ScreenCode IN (N'08002', N'08006')
       AND ActionCode IN (N'CREATE', N'EDIT', N'DELETE')
       AND IsActive = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
