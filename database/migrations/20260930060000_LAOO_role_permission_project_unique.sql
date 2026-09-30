SET XACT_ABORT ON;

-- A role may grant the same menu/action independently in multiple projects.
-- Preserve every permission row; only change the uniqueness boundary.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.TDADRoleGroupPermission')
      AND name=N'UX_TDADRoleGroupPermission_ProjectMenuAction'
)
BEGIN
    CREATE UNIQUE INDEX UX_TDADRoleGroupPermission_ProjectMenuAction
        ON dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode);
END;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.TDADRoleGroupPermission')
      AND name=N'UX_TDADRoleGroupPermission'
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id=OBJECT_ID(N'dbo.TDADRoleGroupPermission')
          AND name=N'UX_TDADRoleGroupPermission' AND is_unique_constraint=1
    )
        ALTER TABLE dbo.TDADRoleGroupPermission DROP CONSTRAINT UX_TDADRoleGroupPermission;
    ELSE
        DROP INDEX UX_TDADRoleGroupPermission ON dbo.TDADRoleGroupPermission;
END;
