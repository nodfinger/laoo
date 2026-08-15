SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;

IF COL_LENGTH('dbo.TDADOrganizationUnit','OwnerType') IS NULL
    ALTER TABLE dbo.TDADOrganizationUnit ADD OwnerType char(1) NOT NULL CONSTRAINT DF_TDADOrganizationUnit_OwnerType DEFAULT('C');
IF COL_LENGTH('dbo.TDADOrganizationUnit','PartnerID') IS NULL
    ALTER TABLE dbo.TDADOrganizationUnit ADD PartnerID bigint NULL;

ALTER TABLE dbo.TDADOrganizationUnit ALTER COLUMN CompanyID bigint NULL;

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_TDADOrganizationUnit_Partner')
    ALTER TABLE dbo.TDADOrganizationUnit ADD CONSTRAINT FK_TDADOrganizationUnit_Partner FOREIGN KEY (PartnerID) REFERENCES dbo.TDADPartner(PartnerID);

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_TDADOrganizationUnit_Code' AND object_id=OBJECT_ID('dbo.TDADOrganizationUnit'))
    DROP INDEX UX_TDADOrganizationUnit_Code ON dbo.TDADOrganizationUnit;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_TDADOrganizationUnit_OwnerCode' AND object_id=OBJECT_ID('dbo.TDADOrganizationUnit'))
    CREATE UNIQUE INDEX UX_TDADOrganizationUnit_OwnerCode
    ON dbo.TDADOrganizationUnit(OwnerType,PartnerID,CompanyID,UnitType,ParentOrgUnitKey,UnitCode);

UPDATE dbo.TDADOrganizationUnit
SET OwnerType='C', PartnerID=NULL
WHERE OwnerType IS NULL;
