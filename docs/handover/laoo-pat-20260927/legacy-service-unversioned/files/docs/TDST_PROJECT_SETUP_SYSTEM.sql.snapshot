/*
  Project-level central settings.
  These values are shared by every Customer under the same ProjectID.
  They are intentionally separate from TDSTCompanySetupSystem.
*/
IF OBJECT_ID(N'dbo.TDSTProjectSetupSystem', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTProjectSetupSystem
    (
        ProjectID BIGINT NOT NULL,
        MaxItemImageSizeMB DECIMAL(10,2) NOT NULL
            CONSTRAINT DF_TDSTProjectSetupSystem_MaxItemImageSizeMB DEFAULT (10),
        MaxBusinessCardImageSizeMB DECIMAL(10,2) NOT NULL
            CONSTRAINT DF_TDSTProjectSetupSystem_MaxBusinessCardImageSizeMB DEFAULT (10),
        IsActive BIT NOT NULL
            CONSTRAINT DF_TDSTProjectSetupSystem_IsActive DEFAULT (1),
        CreateBy BIGINT NULL,
        CreateDate DATETIME2(7) NOT NULL
            CONSTRAINT DF_TDSTProjectSetupSystem_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateBy BIGINT NULL,
        UpdateDate DATETIME2(7) NULL,
        CONSTRAINT PK_TDSTProjectSetupSystem PRIMARY KEY (ProjectID),
        CONSTRAINT CK_TDSTProjectSetupSystem_MaxItemImageSizeMB CHECK (MaxItemImageSizeMB > 0),
        CONSTRAINT CK_TDSTProjectSetupSystem_MaxBusinessCardImageSizeMB CHECK (MaxBusinessCardImageSizeMB > 0)
    );
END;
GO

IF COL_LENGTH(N'dbo.TDSTProjectSetupSystem', N'DescriptionItemImage') IS NULL
    ALTER TABLE dbo.TDSTProjectSetupSystem ADD DescriptionItemImage NVARCHAR(1000) NULL;
GO

IF COL_LENGTH(N'dbo.TDSTProjectSetupSystem', N'DescriptionBusinessCardImage') IS NULL
    ALTER TABLE dbo.TDSTProjectSetupSystem ADD DescriptionBusinessCardImage NVARCHAR(1000) NULL;
GO

/* Add the default row for the current project only when it does not exist. */
IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDSTProjectSetupSystem
    WHERE ProjectID = 1
)
BEGIN
    INSERT dbo.TDSTProjectSetupSystem(ProjectID)
    VALUES (1);
END;
GO
