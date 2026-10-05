SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09007' AND ScreenType=4)
        THROW 59007, N'ไม่พบเมนู 09007 ใบกำกับภาษี ScreenType 4', 1;

    INSERT dbo.TDADPermission
    (
        ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
        ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate
    )
    SELECT PM.ProjectID, N'09007', M.MenuName, N'TAX_INVOICE',
           N'PRINT', N'พิมพ์', N'PRINT', 1, SYSUTCDATETIME()
    FROM dbo.TDADProjectMenu PM
    JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode
    JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.IsActive=1
    WHERE PM.MenuCode=N'09007' AND PM.IsActive=1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.TDADPermission X
          WHERE X.ProjectID=PM.ProjectID AND X.ScreenCode=N'09007' AND X.ActionCode=N'PRINT'
      );

    UPDATE D
       SET D.ScreenNameTH=M.MenuName,
           D.ScreenNameEN=N'TAX_INVOICE',
           D.ActionNameTH=N'พิมพ์',
           D.ActionNameEN=N'PRINT',
           D.IsActive=1,
           D.ModifiedDate=SYSUTCDATETIME()
    FROM dbo.TDADPermission D
    JOIN dbo.TDADMainMenu M ON M.MenuCode=D.ScreenCode
    WHERE D.ScreenCode=N'09007' AND D.ActionCode=N'PRINT';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
