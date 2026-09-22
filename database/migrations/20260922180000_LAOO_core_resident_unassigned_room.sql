SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADResident', N'U') IS NULL
    THROW 53020, N'TDADResident is required.', 1;

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_TDADResident_ExactlyOneLocation' AND parent_object_id=OBJECT_ID(N'dbo.TDADResident'))
    ALTER TABLE dbo.TDADResident DROP CONSTRAINT CK_TDADResident_ExactlyOneLocation;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_TDADResident_LocationAllowed' AND parent_object_id=OBJECT_ID(N'dbo.TDADResident'))
    ALTER TABLE dbo.TDADResident ADD CONSTRAINT CK_TDADResident_LocationAllowed CHECK
    ((RoomID IS NOT NULL AND HouseID IS NULL) OR (RoomID IS NULL AND HouseID IS NOT NULL) OR (RoomID IS NULL AND HouseID IS NULL));
