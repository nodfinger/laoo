-- Core Item responsible department. Existing items remain unassigned.
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDIVItem', N'ResponsibleDepartmentOrgUnitID') IS NULL
    ALTER TABLE dbo.TDIVItem ADD ResponsibleDepartmentOrgUnitID bigint NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name=N'FK_TDIVItem_ResponsibleDepartment'
)
    EXEC sys.sp_executesql N'
        ALTER TABLE dbo.TDIVItem WITH CHECK
        ADD CONSTRAINT FK_TDIVItem_ResponsibleDepartment
        FOREIGN KEY(ResponsibleDepartmentOrgUnitID)
        REFERENCES dbo.TDADOrganizationUnit(OrgUnitID);';

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.TDIVItem')
      AND name=N'IX_TDIVItem_Company_ResponsibleDepartment'
)
    EXEC sys.sp_executesql N'
        CREATE INDEX IX_TDIVItem_Company_ResponsibleDepartment
        ON dbo.TDIVItem(CompanyID, ResponsibleDepartmentOrgUnitID)
        WHERE ResponsibleDepartmentOrgUnitID IS NOT NULL;';
