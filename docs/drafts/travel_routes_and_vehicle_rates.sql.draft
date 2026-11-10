SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDSTTravelRouteRate', N'U') IS NULL
    THROW 54041, N'Travel route rates table is missing.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDSTTravelRouteRate GROUP BY CompanyID, Origin, Destination, DistanceKm, VehicleTypeCode HAVING COUNT(*) > 1)
    THROW 54042, N'Duplicate vehicle rates require review before migration.', 1;

IF OBJECT_ID(N'dbo.TDSTTravelRoute', N'U') IS NULL
    CREATE TABLE dbo.TDSTTravelRoute (
        Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CompanyID bigint NOT NULL,
        Origin nvarchar(200) NOT NULL,
        Destination nvarchar(200) NOT NULL,
        DistanceKm decimal(12,2) NOT NULL CHECK (DistanceKm >= 0),
        CreateBy bigint NOT NULL,
        CreateDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdateBy bigint NULL,
        UpdateDate datetime2 NULL
    );

IF COL_LENGTH(N'dbo.TDSTTravelRouteRate', N'RouteID') IS NULL
    ALTER TABLE dbo.TDSTTravelRouteRate ADD RouteID bigint NULL;

EXEC sys.sp_executesql N'
INSERT dbo.TDSTTravelRoute (CompanyID, Origin, Destination, DistanceKm, CreateBy)
SELECT r.CompanyID, r.Origin, r.Destination, r.DistanceKm, MIN(r.CreateBy)
FROM dbo.TDSTTravelRouteRate r
WHERE r.RouteID IS NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.TDSTTravelRoute p WHERE p.CompanyID=r.CompanyID
    AND p.Origin=r.Origin AND p.Destination=r.Destination AND p.DistanceKm=r.DistanceKm)
GROUP BY r.CompanyID, r.Origin, r.Destination, r.DistanceKm;

UPDATE r SET RouteID = p.Id
FROM dbo.TDSTTravelRouteRate r JOIN dbo.TDSTTravelRoute p
    ON p.CompanyID=r.CompanyID AND p.Origin=r.Origin
    AND p.Destination=r.Destination AND p.DistanceKm=r.DistanceKm
WHERE r.RouteID IS NULL;

IF EXISTS (SELECT 1 FROM dbo.TDSTTravelRouteRate WHERE RouteID IS NULL)
    THROW 54043, N''Travel route rate migration incomplete.'', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N''dbo.TDSTTravelRouteRate'') AND name=N''UX_TravelRouteRate_RouteVehicle'')
    CREATE UNIQUE INDEX UX_TravelRouteRate_RouteVehicle ON dbo.TDSTTravelRouteRate(RouteID, VehicleTypeCode) WHERE RouteID IS NOT NULL;
';

COMMIT;
