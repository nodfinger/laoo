SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTTravelClaim',N'U') IS NULL
CREATE TABLE dbo.TDSTTravelClaim (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY, CompanyID bigint NOT NULL, UserID bigint NOT NULL,
 ClaimNo nvarchar(30) NOT NULL, RequestKey uniqueidentifier NULL, ClaimDate date NOT NULL, RouteID bigint NULL, IsInterbranch bit NOT NULL DEFAULT 0,
 Origin nvarchar(200) NOT NULL, Destination nvarchar(200) NOT NULL, Purpose nvarchar(500) NOT NULL,
 WorkPlace nvarchar(500) NOT NULL, MapUrl nvarchar(1000) NULL,
 DistanceKm decimal(12,2) NOT NULL, StartDate date NOT NULL, EndDate date NOT NULL,
 VehicleTypeCode nvarchar(10) NOT NULL, VehicleRegistration nvarchar(50) NOT NULL,
 RatePerKm decimal(12,2) NULL, FlatFare decimal(12,2) NULL, LodgingRate decimal(12,2) NOT NULL,
 Nights int NOT NULL, Toll decimal(12,2) NOT NULL, Parking decimal(12,2) NOT NULL, PublicTransport decimal(12,2) NOT NULL,
 FuelAmount decimal(16,2) NOT NULL, LodgingAmount decimal(16,2) NOT NULL, TotalAmount decimal(16,2) NOT NULL,
 CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), UpdatedAt datetime2 NULL,
 CONSTRAINT UX_TravelClaim_CompanyNo UNIQUE (CompanyID, ClaimNo),
 CONSTRAINT CK_TravelClaim_Values CHECK (DistanceKm>=0 AND EndDate>=StartDate AND Nights>=0 AND LodgingRate>=0 AND Toll>=0 AND Parking>=0 AND PublicTransport>=0)
);
IF COL_LENGTH(N'dbo.TDSTTravelClaim',N'IsInterbranch') IS NULL
    ALTER TABLE dbo.TDSTTravelClaim ADD IsInterbranch bit NOT NULL CONSTRAINT DF_TravelClaim_IsInterbranch DEFAULT 0;
IF COL_LENGTH(N'dbo.TDSTTravelClaim',N'RequestKey') IS NULL
    ALTER TABLE dbo.TDSTTravelClaim ADD RequestKey uniqueidentifier NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDSTTravelClaim') AND name=N'UX_TravelClaim_RequestKey')
    EXEC(N'CREATE UNIQUE INDEX UX_TravelClaim_RequestKey ON dbo.TDSTTravelClaim(CompanyID,UserID,RequestKey) WHERE RequestKey IS NOT NULL');
IF OBJECT_ID(N'dbo.TDSTTravelClaimAttachment',N'U') IS NULL
CREATE TABLE dbo.TDSTTravelClaimAttachment (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY, ClaimID bigint NOT NULL, CompanyID bigint NOT NULL,
 FileName nvarchar(255) NOT NULL, ContentType varchar(100) NOT NULL, FileData varbinary(max) NOT NULL,
 CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT FK_TravelClaimAttachment_Claim FOREIGN KEY(ClaimID) REFERENCES dbo.TDSTTravelClaim(Id)
);
UPDATE dbo.TDADMainMenu SET RunData=1,AllowListDisplaySettings=1 WHERE MenuCode=N'66001' AND ScreenType=4;
