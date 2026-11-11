IF COL_LENGTH(N'dbo.TDSTTravelClaim', N'StartTime') IS NULL
    ALTER TABLE dbo.TDSTTravelClaim ADD StartTime time(0) NULL;
IF COL_LENGTH(N'dbo.TDSTTravelClaim', N'EndTime') IS NULL
    ALTER TABLE dbo.TDSTTravelClaim ADD EndTime time(0) NULL;
