SET NOCOUNT ON;
SET XACT_ABORT ON;
IF COL_LENGTH(N'dbo.TDSTTravelClaim',N'RequestHash') IS NULL
    ALTER TABLE dbo.TDSTTravelClaim ADD RequestHash varbinary(32) NULL;
