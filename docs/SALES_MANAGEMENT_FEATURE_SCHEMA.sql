/*
  SALES_MANAGEMENT option
  Scope: Partner Admin enables/disables the option for a Customer company.
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADFeature', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADFeature
    (
        FeatureCode        nvarchar(50)  NOT NULL CONSTRAINT PK_TDADFeature PRIMARY KEY,
        FeatureName        nvarchar(200) NOT NULL,
        FeatureDescription nvarchar(1000) NULL,
        IsActive            bit NOT NULL CONSTRAINT DF_TDADFeature_IsActive DEFAULT (1),
        SortOrder           int NOT NULL CONSTRAINT DF_TDADFeature_SortOrder DEFAULT (0),
        CreateDate          datetime2(3) NOT NULL CONSTRAINT DF_TDADFeature_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreatedBy           bigint NULL,
        UpdateDate          datetime2(3) NULL,
        UpdatedBy           bigint NULL
    );
END;

IF OBJECT_ID(N'dbo.TDADCompanyFeature', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADCompanyFeature
    (
        CompanyFeatureID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADCompanyFeature PRIMARY KEY,
        ProjectID        bigint NOT NULL,
        PartnerID        bigint NOT NULL,
        CompanyID        bigint NOT NULL,
        FeatureCode      nvarchar(50) NOT NULL,
        IsEnabled        bit NOT NULL CONSTRAINT DF_TDADCompanyFeature_IsEnabled DEFAULT (0),
        IsTrial          bit NOT NULL CONSTRAINT DF_TDADCompanyFeature_IsTrial DEFAULT (0),
        StartDate        date NULL,
        ExpireDate       date NULL,
        CreateDate       datetime2(3) NOT NULL CONSTRAINT DF_TDADCompanyFeature_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreatedBy        bigint NULL,
        UpdateDate       datetime2(3) NULL,
        UpdatedBy        bigint NULL,
        CONSTRAINT UQ_TDADCompanyFeature_Scope UNIQUE (ProjectID, CompanyID, FeatureCode)
    );
END;

IF OBJECT_ID(N'dbo.TDADCompanyFeatureHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADCompanyFeatureHistory
    (
        CompanyFeatureHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADCompanyFeatureHistory PRIMARY KEY,
        CompanyFeatureID       bigint NOT NULL,
        OldIsEnabled           bit NULL,
        NewIsEnabled           bit NOT NULL,
        OldIsTrial             bit NULL,
        NewIsTrial             bit NOT NULL,
        OldStartDate           date NULL,
        NewStartDate           date NULL,
        OldExpireDate          date NULL,
        NewExpireDate          date NULL,
        ChangeReason           nvarchar(500) NULL,
        ChangedDate            datetime2(3) NOT NULL CONSTRAINT DF_TDADCompanyFeatureHistory_ChangedDate DEFAULT (SYSUTCDATETIME()),
        ChangedBy              bigint NULL
    );
END;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode = N'SALES_MANAGEMENT')
BEGIN
    INSERT dbo.TDADFeature
    (
        FeatureCode, FeatureName, FeatureDescription, IsActive, SortOrder
    )
    VALUES
    (
        N'SALES_MANAGEMENT',
        N'บริหารงานขาย',
        N'ระบบสถานะลูกค้า ประวัติการติดต่อ การมอบหมาย Sales และงานติดตาม',
        1,
        1
    );
END
ELSE
BEGIN
    UPDATE dbo.TDADFeature
    SET FeatureName = N'บริหารงานขาย',
        FeatureDescription = N'ระบบสถานะลูกค้า ประวัติการติดต่อ การมอบหมาย Sales และงานติดตาม',
        IsActive = 1
    WHERE FeatureCode = N'SALES_MANAGEMENT';
END;

COMMIT TRANSACTION;

SELECT FeatureCode, FeatureName, IsActive
FROM dbo.TDADFeature
WHERE FeatureCode = N'SALES_MANAGEMENT';
