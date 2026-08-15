USE [DBTDLaoo]
GO
SET XACT_ABORT ON
GO
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.TDADRoleGroupPermission', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADRoleGroupPermission
    (
        RoleGroupPermissionID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADRoleGroupPermission PRIMARY KEY,
        RoleGroupID BIGINT NOT NULL,
        ProjectID BIGINT NOT NULL,
        MenuCode NVARCHAR(20) NOT NULL,
        ActionCode NVARCHAR(50) NOT NULL,
        IsAllowed BIT NOT NULL CONSTRAINT DF_TDADRoleGroupPermission_IsAllowed DEFAULT(1),
        CreatedUtc DATETIME2(3) NOT NULL CONSTRAINT DF_TDADRoleGroupPermission_CreatedUtc DEFAULT(SYSUTCDATETIME()),
        CreatedBy NVARCHAR(100) NOT NULL,
        UpdatedUtc DATETIME2(3) NULL,
        UpdatedBy NVARCHAR(100) NULL,
        CONSTRAINT FK_TDADRoleGroupPermission_RoleGroup FOREIGN KEY(RoleGroupID) REFERENCES dbo.TDADRoleGroup(RoleGroupID),
        CONSTRAINT FK_TDADRoleGroupPermission_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT UX_TDADRoleGroupPermission UNIQUE(RoleGroupID, MenuCode, ActionCode)
    );
END;
COMMIT TRANSACTION;
GO
