SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMVisitorAppointment', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.TDTMVisitorAppointment', N'HostTenantID') IS NULL
BEGIN
    ALTER TABLE dbo.TDTMVisitorAppointment
        ADD HostTenantID bigint NULL;
END;

IF OBJECT_ID(N'dbo.TDTMVisitorAppointment', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.TDTMVisitorAppointment')
         AND name = N'IX_TDTMVisitorAppointment_RentalHost'
   )
BEGIN
    CREATE INDEX IX_TDTMVisitorAppointment_RentalHost
        ON dbo.TDTMVisitorAppointment(CompanyID, HostTenantID, HostTenantContactID, StatusCode);
END;

COMMIT TRANSACTION;
