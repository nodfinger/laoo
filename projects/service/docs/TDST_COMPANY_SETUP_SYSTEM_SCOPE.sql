/*
  Add ownership scope to system-level generation settings.
  Run once on DBTDLaoo after checking the target database.
*/

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'PKValue') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD PKValue BIGINT IDENTITY(1,1) NOT NULL;
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'ProjectID') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD ProjectID BIGINT NULL;
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'OwnerType') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD OwnerType CHAR(1) NULL;
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'PartnerID') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD PartnerID BIGINT NULL;
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'CompanyID') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD CompanyID BIGINT NULL;
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'IsActive') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD IsActive BIT NOT NULL CONSTRAINT DF_TDSTCompanySetupSystem_IsActive DEFAULT (1);
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'CreateDate') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD CreateDate DATETIME2(7) NOT NULL CONSTRAINT DF_TDSTCompanySetupSystem_CreateDate DEFAULT (SYSUTCDATETIME());
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystem', N'UpdateDate') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystem
        ADD UpdateDate DATETIME2(7) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.TDSTCompanySetupSystem')
      AND name=N'UX_TDSTCompanySetupSystem_Scope'
)
    CREATE UNIQUE INDEX UX_TDSTCompanySetupSystem_Scope
    ON dbo.TDSTCompanySetupSystem(ProjectID,OwnerType,PartnerID,CompanyID);
GO
