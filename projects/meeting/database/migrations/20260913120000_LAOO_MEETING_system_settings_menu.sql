/*
 Core owns TDADMainMenu. 05003 (company setup additional) is the single host
 for project setting panels; Meeting must not create a separate main menu.
 The Meeting API owns /api/company/meeting-equipment-requests/settings.
 Its TDSTCompanySetupSystemMeeting default is false, so existing requests remain unchanged.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO_MEETING' AND IsActive=1
    )
        THROW 51000, N'Active LAOO_MEETING project was not found.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADMainMenu
        WHERE MenuCode=N'05003' AND IsActive=1
    )
        THROW 51001, N'Active Core menu 05003 is required for additional system settings.', 1;

    IF OBJECT_ID(N'dbo.TDSTCompanySetupSystemMeeting',N'U') IS NULL
        THROW 51002, N'Meeting equipment request settings table is required.', 1;

    /*
      Intentionally no TDADMainMenu, TDADProjectMenu, or TDADPermission writes.
      Menu 22006 violates Core menu-code validation and is replaced by the
      Meeting panel hosted in Core menu 05003.
    */
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO