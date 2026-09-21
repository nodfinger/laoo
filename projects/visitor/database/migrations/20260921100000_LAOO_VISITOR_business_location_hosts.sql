/* LAOO_VISITOR: references and immutable snapshots for shared business-location hosts. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostTenantID') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostTenantID bigint NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostTenantContactID') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostTenantContactID bigint NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostLocationSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostLocationSnapshot nvarchar(500) NULL;

EXEC sys.sp_executesql N'
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name=N''CK_TDTMVisitorVisit_HostType''
             AND parent_object_id=OBJECT_ID(N''dbo.TDTMVisitorVisit''))
    ALTER TABLE dbo.TDTMVisitorVisit DROP CONSTRAINT CK_TDTMVisitorVisit_HostType;
ALTER TABLE dbo.TDTMVisitorVisit ADD CONSTRAINT CK_TDTMVisitorVisit_HostType
    CHECK(HostType IN(''EMPLOYEE'',''RESIDENT'',''SERVICE_CUSTOMER'',
                      ''RENTAL_OFFICE'',''VILLAGE''));
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id=OBJECT_ID(N''dbo.TDTMVisitorVisit'')
                 AND name=N''IX_TDTMVisitorVisit_Company_TenantContact'')
    CREATE INDEX IX_TDTMVisitorVisit_Company_TenantContact
        ON dbo.TDTMVisitorVisit(CompanyID,HostTenantID,HostTenantContactID,StatusCode);';

COMMIT TRANSACTION;
