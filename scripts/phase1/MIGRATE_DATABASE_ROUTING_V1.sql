USE [DBTDLaoo]
GO

SET XACT_ABORT ON
GO

BEGIN TRANSACTION
GO

IF OBJECT_ID(N'dbo.TDSYDatabaseEndpoint', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSYDatabaseEndpoint
    (
        DatabaseEndpointID bigint IDENTITY(1,1) NOT NULL,
        EndpointCode nvarchar(50) NOT NULL,
        EnvironmentCode nvarchar(20) NOT NULL,
        ConnectionKey nvarchar(100) NOT NULL,
        DatabaseName nvarchar(128) NOT NULL,
        SchemaName nvarchar(128) NOT NULL
            CONSTRAINT DF_TDSYDatabaseEndpoint_SchemaName DEFAULT N'dbo',
        RequiredSchemaVersion nvarchar(30) NULL,
        IsActive bit NOT NULL
            CONSTRAINT DF_TDSYDatabaseEndpoint_IsActive DEFAULT (1),
        LastHealthCheckDate datetime2(0) NULL,
        LastHealthCheckSucceeded bit NULL,
        LastHealthMessage nvarchar(1000) NULL,
        CreateDate datetime2(0) NOT NULL
            CONSTRAINT DF_TDSYDatabaseEndpoint_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        UpdateDate datetime2(0) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT PK_TDSYDatabaseEndpoint PRIMARY KEY (DatabaseEndpointID),
        CONSTRAINT UQ_TDSYDatabaseEndpoint_EndpointCode UNIQUE (EndpointCode),
        CONSTRAINT CK_TDSYDatabaseEndpoint_Environment CHECK
            (EnvironmentCode IN (N'DEVELOPMENT', N'UAT', N'PRODUCTION')),
        CONSTRAINT CK_TDSYDatabaseEndpoint_ConnectionKey_NotBlank CHECK
            (LEN(LTRIM(RTRIM(ConnectionKey))) > 0),
        CONSTRAINT CK_TDSYDatabaseEndpoint_DatabaseName_NotBlank CHECK
            (LEN(LTRIM(RTRIM(DatabaseName))) > 0)
    );
END
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADCompany')
      AND name = N'UQ_TDADCompany_Partner_CompanyID'
)
BEGIN
    CREATE UNIQUE INDEX UQ_TDADCompany_Partner_CompanyID
        ON dbo.TDADCompany(PartnerID, CompanyID);
END
GO

IF OBJECT_ID(N'dbo.TDSYDatabaseRoute', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSYDatabaseRoute
    (
        DatabaseRouteID bigint IDENTITY(1,1) NOT NULL,
        ProjectID bigint NOT NULL,
        EnvironmentCode nvarchar(20) NOT NULL,
        ScopeType char(1) NOT NULL,
        PartnerID bigint NULL,
        CompanyID bigint NULL,
        DatabaseEndpointID bigint NOT NULL,
        IsActive bit NOT NULL
            CONSTRAINT DF_TDSYDatabaseRoute_IsActive DEFAULT (1),
        EffectiveFrom datetime2(0) NULL,
        EffectiveTo datetime2(0) NULL,
        CreateDate datetime2(0) NOT NULL
            CONSTRAINT DF_TDSYDatabaseRoute_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        UpdateDate datetime2(0) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT PK_TDSYDatabaseRoute PRIMARY KEY (DatabaseRouteID),
        CONSTRAINT FK_TDSYDatabaseRoute_Project FOREIGN KEY (ProjectID)
            REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT FK_TDSYDatabaseRoute_Endpoint FOREIGN KEY (DatabaseEndpointID)
            REFERENCES dbo.TDSYDatabaseEndpoint(DatabaseEndpointID),
        CONSTRAINT FK_TDSYDatabaseRoute_Partner FOREIGN KEY (PartnerID)
            REFERENCES dbo.TDADPartner(PartnerID),
        CONSTRAINT FK_TDSYDatabaseRoute_CompanyPartner FOREIGN KEY (PartnerID, CompanyID)
            REFERENCES dbo.TDADCompany(PartnerID, CompanyID),
        CONSTRAINT CK_TDSYDatabaseRoute_Environment CHECK
            (EnvironmentCode IN (N'DEVELOPMENT', N'UAT', N'PRODUCTION')),
        CONSTRAINT CK_TDSYDatabaseRoute_Scope CHECK
        (
            (ScopeType = 'D' AND PartnerID IS NULL AND CompanyID IS NULL)
            OR (ScopeType = 'P' AND PartnerID IS NOT NULL AND CompanyID IS NULL)
            OR (ScopeType = 'C' AND PartnerID IS NOT NULL AND CompanyID IS NOT NULL)
        ),
        CONSTRAINT CK_TDSYDatabaseRoute_EffectiveDate CHECK
            (EffectiveTo IS NULL OR EffectiveFrom IS NULL OR EffectiveTo > EffectiveFrom)
    );

    CREATE UNIQUE INDEX UX_TDSYDatabaseRoute_Default_Active
        ON dbo.TDSYDatabaseRoute(ProjectID, EnvironmentCode)
        WHERE ScopeType = 'D' AND IsActive = 1;

    CREATE UNIQUE INDEX UX_TDSYDatabaseRoute_Partner_Active
        ON dbo.TDSYDatabaseRoute(ProjectID, EnvironmentCode, PartnerID)
        WHERE ScopeType = 'P' AND IsActive = 1;

    CREATE UNIQUE INDEX UX_TDSYDatabaseRoute_Company_Active
        ON dbo.TDSYDatabaseRoute(ProjectID, EnvironmentCode, CompanyID)
        WHERE ScopeType = 'C' AND IsActive = 1;

    CREATE INDEX IX_TDSYDatabaseRoute_Resolve
        ON dbo.TDSYDatabaseRoute
        (ProjectID, EnvironmentCode, CompanyID, PartnerID, ScopeType, IsActive)
        INCLUDE (DatabaseEndpointID, EffectiveFrom, EffectiveTo);
END
GO

/* Seed current project database registrations as default endpoints/routes. */
INSERT dbo.TDSYDatabaseEndpoint
(
    EndpointCode, EnvironmentCode, ConnectionKey, DatabaseName,
    SchemaName, IsActive, CreateDate
)
SELECT
    CONCAT(N'PROJECT_', pd.ProjectID, N'_', pd.EnvironmentCode),
    pd.EnvironmentCode,
    pd.ConnectionKey,
    pd.DatabaseName,
    pd.SchemaName,
    pd.IsActive,
    SYSUTCDATETIME()
FROM dbo.TDADProjectDatabase AS pd
WHERE pd.IsActive = 1
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.TDSYDatabaseEndpoint AS e
      WHERE e.EndpointCode =
          CONCAT(N'PROJECT_', pd.ProjectID, N'_', pd.EnvironmentCode)
  );
GO

INSERT dbo.TDSYDatabaseRoute
(
    ProjectID, EnvironmentCode, ScopeType, PartnerID, CompanyID,
    DatabaseEndpointID, IsActive, CreateDate
)
SELECT
    pd.ProjectID,
    pd.EnvironmentCode,
    'D',
    NULL,
    NULL,
    e.DatabaseEndpointID,
    1,
    SYSUTCDATETIME()
FROM dbo.TDADProjectDatabase AS pd
JOIN dbo.TDSYDatabaseEndpoint AS e
  ON e.EndpointCode = CONCAT(N'PROJECT_', pd.ProjectID, N'_', pd.EnvironmentCode)
WHERE pd.IsActive = 1
  AND pd.IsDefault = 1
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.TDSYDatabaseRoute AS r
      WHERE r.ProjectID = pd.ProjectID
        AND r.EnvironmentCode = pd.EnvironmentCode
        AND r.ScopeType = 'D'
        AND r.IsActive = 1
  );
GO

IF NOT EXISTS
(
    SELECT 1 FROM dbo.TDSYDatabaseVersion
    WHERE ProjectCode = N'LAOO' AND VersionNumber = N'1.1.0'
)
BEGIN
    INSERT dbo.TDSYDatabaseVersion
        (ProjectCode, VersionNumber, DescriptionText, AppliedDate)
    VALUES
        (N'LAOO', N'1.1.0', N'Company-Partner-Default database routing registry', SYSUTCDATETIME());
END
GO

COMMIT TRANSACTION
GO

/*
Resolution query parameters:
  @ProjectID bigint, @EnvironmentCode nvarchar(20),
  @CompanyID bigint = NULL, @PartnerID bigint = NULL

SELECT TOP (1)
    r.DatabaseRouteID, r.ScopeType, e.ConnectionKey,
    e.DatabaseName, e.SchemaName, e.RequiredSchemaVersion
FROM dbo.TDSYDatabaseRoute AS r
JOIN dbo.TDSYDatabaseEndpoint AS e
  ON e.DatabaseEndpointID = r.DatabaseEndpointID
 AND e.IsActive = 1
WHERE r.ProjectID = @ProjectID
  AND r.EnvironmentCode = @EnvironmentCode
  AND r.IsActive = 1
  AND (r.EffectiveFrom IS NULL OR r.EffectiveFrom <= SYSUTCDATETIME())
  AND (r.EffectiveTo IS NULL OR r.EffectiveTo > SYSUTCDATETIME())
  AND
  (
      (r.ScopeType = 'C' AND r.CompanyID = @CompanyID)
      OR (r.ScopeType = 'P' AND r.PartnerID = @PartnerID)
      OR r.ScopeType = 'D'
  )
ORDER BY CASE r.ScopeType WHEN 'C' THEN 1 WHEN 'P' THEN 2 ELSE 3 END;
*/
