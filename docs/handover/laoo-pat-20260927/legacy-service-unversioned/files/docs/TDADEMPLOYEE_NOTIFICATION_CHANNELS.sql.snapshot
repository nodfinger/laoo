/*
  Notification channels for employees.
  Existing employees default to in-system notifications.
  This script is idempotent and can be run again safely.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.TDADEmployee', N'NotifyByEmail') IS NULL
    BEGIN
        ALTER TABLE dbo.TDADEmployee
        ADD NotifyByEmail bit NOT NULL
            CONSTRAINT DF_TDADEmployee_NotifyByEmail DEFAULT (0) WITH VALUES;
    END;

    IF COL_LENGTH(N'dbo.TDADEmployee', N'NotifyInSystem') IS NULL
    BEGIN
        ALTER TABLE dbo.TDADEmployee
        ADD NotifyInSystem bit NOT NULL
            CONSTRAINT DF_TDADEmployee_NotifyInSystem DEFAULT (1) WITH VALUES;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.TDADEmployee')
          AND name = N'CK_TDADEmployee_NotificationChannel'
    )
    BEGIN
        ALTER TABLE dbo.TDADEmployee WITH CHECK
        ADD CONSTRAINT CK_TDADEmployee_NotificationChannel
            CHECK (NotifyByEmail = 1 OR NotifyInSystem = 1);
    END;

    COMMIT TRANSACTION;

    SELECT
        COL_LENGTH(N'dbo.TDADEmployee', N'NotifyByEmail') AS NotifyByEmailLength,
        COL_LENGTH(N'dbo.TDADEmployee', N'NotifyInSystem') AS NotifyInSystemLength;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
