SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostType') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostType varchar(20) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostResidentID') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostResidentID bigint NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'BusinessTypeCodeSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD BusinessTypeCodeSnapshot varchar(20) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostNameSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostNameSnapshot nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDTMVisitorVisit', N'HostRoomSnapshot') IS NULL
    ALTER TABLE dbo.TDTMVisitorVisit ADD HostRoomSnapshot nvarchar(100) NULL;

EXEC sys.sp_executesql N'
UPDATE V
SET HostType = ISNULL(NULLIF(V.HostType,''''),''EMPLOYEE''),
    BusinessTypeCodeSnapshot = ISNULL(NULLIF(V.BusinessTypeCodeSnapshot,''''),
        ISNULL(NULLIF(UPPER(LTRIM(RTRIM(C.BusinessTypeCode))),''''),''COMPANY'')),
    HostNameSnapshot = ISNULL(V.HostNameSnapshot,E.FullName)
FROM dbo.TDTMVisitorVisit V
LEFT JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=V.CompanyID
LEFT JOIN dbo.TDADEmployee E ON E.CompanyID=V.CompanyID AND E.EmployeeID=V.HostEmployeeID
WHERE V.HostType IS NULL OR V.BusinessTypeCodeSnapshot IS NULL OR V.HostNameSnapshot IS NULL;';

EXEC sys.sp_executesql N'
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N''CK_TDTMVisitorVisit_HostType'')
    ALTER TABLE dbo.TDTMVisitorVisit ADD CONSTRAINT CK_TDTMVisitorVisit_HostType
        CHECK(HostType IN(''EMPLOYEE'',''RESIDENT''));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N''IX_TDTMVisitorVisit_HostResident''
              AND object_id=OBJECT_ID(N''dbo.TDTMVisitorVisit''))
    CREATE INDEX IX_TDTMVisitorVisit_HostResident
        ON dbo.TDTMVisitorVisit(CompanyID,HostResidentID,StatusCode);';

COMMIT TRANSACTION;
