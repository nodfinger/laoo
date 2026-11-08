SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADEmployee', N'U') IS NULL
    THROW 53701, N'Employee table is missing.', 1;
IF COL_LENGTH(N'dbo.TDADEmployee', N'NotifyByEmail') IS NULL
    ALTER TABLE dbo.TDADEmployee ADD NotifyByEmail bit NOT NULL
        CONSTRAINT DF_TDADEmployee_NotifyByEmail DEFAULT (0) WITH VALUES;
