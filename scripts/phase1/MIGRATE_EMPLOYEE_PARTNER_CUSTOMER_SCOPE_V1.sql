USE [DBTDLaoo];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDADEmployee', N'PartnerID') IS NULL
    ALTER TABLE dbo.TDADEmployee ADD PartnerID bigint NULL;
GO

EXEC sys.sp_executesql N'
UPDATE E
SET PartnerID = C.PartnerID
FROM dbo.TDADEmployee AS E
INNER JOIN dbo.TDADCompany AS C ON C.CompanyID = E.CompanyID
WHERE E.PartnerID IS NULL;';

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_TDADEmployee_Company_Code' AND object_id = OBJECT_ID(N'dbo.TDADEmployee'))
    DROP INDEX UX_TDADEmployee_Company_Code ON dbo.TDADEmployee;

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_TDADEmployee_Partner')
    ALTER TABLE dbo.TDADEmployee ADD CONSTRAINT FK_TDADEmployee_Partner
        FOREIGN KEY (PartnerID) REFERENCES dbo.TDADPartner(PartnerID);

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_TDADEmployee_OwnerScope')
    ALTER TABLE dbo.TDADEmployee ADD CONSTRAINT CK_TDADEmployee_OwnerScope CHECK (PartnerID IS NOT NULL);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_TDADEmployee_CompanyPartner')
    ALTER TABLE dbo.TDADEmployee ADD CONSTRAINT FK_TDADEmployee_CompanyPartner
        FOREIGN KEY (PartnerID, CompanyID) REFERENCES dbo.TDADCompany(PartnerID, CompanyID);

ALTER TABLE dbo.TDADEmployee ALTER COLUMN CompanyID bigint NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_TDADEmployee_Partner_Code' AND object_id = OBJECT_ID(N'dbo.TDADEmployee'))
    CREATE UNIQUE INDEX UX_TDADEmployee_Partner_Code
        ON dbo.TDADEmployee(PartnerID, EmployeeCode)
        WHERE CompanyID IS NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_TDADEmployee_Company_Code' AND object_id = OBJECT_ID(N'dbo.TDADEmployee'))
    CREATE UNIQUE INDEX UX_TDADEmployee_Company_Code
        ON dbo.TDADEmployee(CompanyID, EmployeeCode)
        WHERE CompanyID IS NOT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_TDADEmployee_Partner_Company' AND object_id = OBJECT_ID(N'dbo.TDADEmployee'))
    CREATE INDEX IX_TDADEmployee_Partner_Company
        ON dbo.TDADEmployee(PartnerID, CompanyID, IsActive);

COMMIT TRANSACTION;
