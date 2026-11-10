SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTCompanySetupSystemService', N'U') IS NULL
    THROW 53711, N'Service settings table is missing.', 1;
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService', N'SelfViewScope') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD SelfViewScope varchar(12) NOT NULL CONSTRAINT DF_Service_SelfViewScope DEFAULT ('SELF') WITH VALUES;
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService', N'SelfDepartmentHeadEdit') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD SelfDepartmentHeadEdit bit NOT NULL CONSTRAINT DF_Service_DepHeadEdit DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService', N'SelfDivisionManagerEdit') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD SelfDivisionManagerEdit bit NOT NULL CONSTRAINT DF_Service_DivManagerEdit DEFAULT (0) WITH VALUES;
