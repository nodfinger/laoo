SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostServiceCustomerID') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostServiceCustomerID bigint NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostRoomID') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostRoomID bigint NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'ResidentNameSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD ResidentNameSnapshot nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'BuildingNameSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD BuildingNameSnapshot nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'FloorNameSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD FloorNameSnapshot nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'RoomNameSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD RoomNameSnapshot nvarchar(200) NULL;

EXEC sys.sp_executesql N'
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N''CK_TDTMVisitorVisit_HostType''
          AND parent_object_id=OBJECT_ID(N''dbo.TDTMVisitorVisit''))
    ALTER TABLE dbo.TDTMVisitorVisit DROP CONSTRAINT CK_TDTMVisitorVisit_HostType;
ALTER TABLE dbo.TDTMVisitorVisit ADD CONSTRAINT CK_TDTMVisitorVisit_HostType
    CHECK(HostType IN(''EMPLOYEE'',''RESIDENT'',''SERVICE_CUSTOMER''));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N''IX_TDTMVisitorVisit_HostServiceCustomer''
              AND object_id=OBJECT_ID(N''dbo.TDTMVisitorVisit''))
    CREATE INDEX IX_TDTMVisitorVisit_HostServiceCustomer
        ON dbo.TDTMVisitorVisit(CompanyID,HostServiceCustomerID,StatusCode);';

COMMIT TRANSACTION;
