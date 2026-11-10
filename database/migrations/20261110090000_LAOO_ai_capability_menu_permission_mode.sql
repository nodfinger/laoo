SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADAiCapabilityRolePolicy', N'U') IS NULL
    THROW 53970, N'AI capability role policy table is missing.', 1;
IF COL_LENGTH(N'dbo.TDADAiCapabilityRolePolicy', N'UseMenuPermissions') IS NULL
    ALTER TABLE dbo.TDADAiCapabilityRolePolicy
        ADD UseMenuPermissions bit NOT NULL
            CONSTRAINT DF_TDADAiCapabilityRolePolicy_UseMenuPermissions DEFAULT (0) WITH VALUES;
