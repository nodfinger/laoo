SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTCompanySetupSystemService', N'U') IS NULL
    THROW 53711, N'Service settings table is missing.', 1;
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService', N'SelfDepartmentHeadDelete') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD SelfDepartmentHeadDelete bit NOT NULL CONSTRAINT DF_Service_DepHeadDelete DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService', N'SelfDivisionManagerDelete') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD SelfDivisionManagerDelete bit NOT NULL CONSTRAINT DF_Service_DivManagerDelete DEFAULT (0) WITH VALUES;
