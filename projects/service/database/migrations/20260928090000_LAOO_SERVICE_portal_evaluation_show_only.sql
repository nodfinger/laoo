/* Menu 20005 is a ShowOnly entry point; evaluation answers remain owned by Evaluation. */
BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'20005' AND RouteName = N'portalEvaluation')
        THROW 52005, 'Service portal evaluation menu 20005 is missing or has a different route.', 1;

    UPDATE dbo.TDADMainMenu
       SET ScreenType = 3,
           UpdateDate = SYSUTCDATETIME()
     WHERE MenuCode = N'20005'
       AND ScreenType <> 3;

    UPDATE dbo.TDADPermission
       SET IsActive = 0,
           ModifiedDate = SYSUTCDATETIME()
     WHERE ScreenCode = N'20005'
       AND ActionCode IN (N'CREATE', N'EDIT', N'DELETE')
       AND IsActive = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
