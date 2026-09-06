USE [DBTDMeeting];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDADEmployee', N'NotifyByEmail') IS NULL
BEGIN
    ALTER TABLE dbo.TDADEmployee
        ADD NotifyByEmail bit NOT NULL
            CONSTRAINT DF_TDADEmployee_NotifyByEmail DEFAULT (0) WITH VALUES;
END;

IF COL_LENGTH(N'dbo.TDADEmployee', N'NotifyBySystem') IS NULL
BEGIN
    ALTER TABLE dbo.TDADEmployee
        ADD NotifyBySystem bit NOT NULL
            CONSTRAINT DF_TDADEmployee_NotifyBySystem DEFAULT (1) WITH VALUES;
END;

COMMIT TRANSACTION;
GO
