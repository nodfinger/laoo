SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDADMainMenu', N'AllowListDisplaySettings') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMainMenu ADD AllowListDisplaySettings bit NOT NULL
        CONSTRAINT DF_TDADMainMenu_AllowListDisplaySettings DEFAULT (0) WITH VALUES;
    EXEC sys.sp_executesql N'UPDATE dbo.TDADMainMenu SET AllowListDisplaySettings=1 WHERE MenuCode IN (N''10003'',N''10008'');';
END;
