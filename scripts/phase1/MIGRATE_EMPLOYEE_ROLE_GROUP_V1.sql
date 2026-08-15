/*
  Employee -> Role Group assignment
  Scope/ownership is validated by the API when assigning a group.
  This migration only creates the history table and indexes.
*/
USE [DBTDLaoo];
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADEmployeeRoleGroup', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADEmployeeRoleGroup
    (
        EmployeeRoleGroupID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADEmployeeRoleGroup PRIMARY KEY,
        EmployeeID BIGINT NOT NULL,
        RoleGroupID BIGINT NOT NULL,
        EffectiveFrom DATE NOT NULL
            CONSTRAINT DF_TDADEmployeeRoleGroup_EffectiveFrom DEFAULT (CONVERT(date, SYSUTCDATETIME())),
        EffectiveTo DATE NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_TDADEmployeeRoleGroup_IsActive DEFAULT (1),
        CreatedUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_TDADEmployeeRoleGroup_CreatedUtc DEFAULT (SYSUTCDATETIME()),
        CreatedBy NVARCHAR(100) NOT NULL,
        UpdatedUtc DATETIME2(3) NULL,
        UpdatedBy NVARCHAR(100) NULL,

        CONSTRAINT FK_TDADEmployeeRoleGroup_Employee
            FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT FK_TDADEmployeeRoleGroup_RoleGroup
            FOREIGN KEY (RoleGroupID) REFERENCES dbo.TDADRoleGroup(RoleGroupID),
        CONSTRAINT CK_TDADEmployeeRoleGroup_DateRange
            CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom)
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_TDADEmployeeRoleGroup_EmployeeActiveDate'
      AND object_id = OBJECT_ID(N'dbo.TDADEmployeeRoleGroup')
)
BEGIN
    CREATE INDEX IX_TDADEmployeeRoleGroup_EmployeeActiveDate
        ON dbo.TDADEmployeeRoleGroup(EmployeeID, IsActive, EffectiveFrom, EffectiveTo);
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_TDADEmployeeRoleGroup_RoleGroup'
      AND object_id = OBJECT_ID(N'dbo.TDADEmployeeRoleGroup')
)
BEGIN
    CREATE INDEX IX_TDADEmployeeRoleGroup_RoleGroup
        ON dbo.TDADEmployeeRoleGroup(RoleGroupID, IsActive, EffectiveFrom);
END;

COMMIT TRANSACTION;
GO
