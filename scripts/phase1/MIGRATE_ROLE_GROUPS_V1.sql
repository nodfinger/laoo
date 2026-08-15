USE [DBTDLaoo]
GO

SET XACT_ABORT ON
GO

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADRoleGroup', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADRoleGroup
    (
        RoleGroupID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADRoleGroup PRIMARY KEY,
        ProjectID BIGINT NOT NULL,
        ScopeType CHAR(1) NOT NULL,
        PartnerID BIGINT NULL,
        CompanyID BIGINT NULL,
        RoleCode NVARCHAR(50) NOT NULL,
        RoleNameTH NVARCHAR(200) NOT NULL,
        Description NVARCHAR(500) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDADRoleGroup_IsActive DEFAULT(1),
        CreatedUtc DATETIME2(3) NOT NULL CONSTRAINT DF_TDADRoleGroup_CreatedUtc DEFAULT(SYSUTCDATETIME()),
        CreatedBy NVARCHAR(100) NOT NULL,
        UpdatedUtc DATETIME2(3) NULL,
        UpdatedBy NVARCHAR(100) NULL,
        CONSTRAINT FK_TDADRoleGroup_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT CK_TDADRoleGroup_Scope CHECK (ScopeType IN ('C','P')),
        CONSTRAINT CK_TDADRoleGroup_Owner CHECK
        ((ScopeType='C' AND CompanyID IS NOT NULL AND PartnerID IS NULL)
          OR (ScopeType='P' AND PartnerID IS NOT NULL AND CompanyID IS NULL))
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'UX_TDADRoleGroup_ProjectScopeOwnerCode' AND object_id=OBJECT_ID(N'dbo.TDADRoleGroup'))
    CREATE UNIQUE INDEX UX_TDADRoleGroup_ProjectScopeOwnerCode
        ON dbo.TDADRoleGroup(ProjectID, ScopeType, PartnerID, CompanyID, RoleCode);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name=N'IX_TDADRoleGroup_ProjectScopeOwnerActive' AND object_id=OBJECT_ID(N'dbo.TDADRoleGroup'))
    CREATE INDEX IX_TDADRoleGroup_ProjectScopeOwnerActive
        ON dbo.TDADRoleGroup(ProjectID, ScopeType, PartnerID, CompanyID, IsActive, RoleNameTH);

COMMIT TRANSACTION;
GO

DECLARE @ProjectID BIGINT = (SELECT TOP 1 ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
DECLARE @Menus TABLE(MenuCode NVARCHAR(20), MenuName NVARCHAR(200), RouteName NVARCHAR(100), RoutePath NVARCHAR(200), ScopeCode NVARCHAR(10));
INSERT @Menus VALUES
(N'10003',N'กลุ่มสิทธิ์',N'companyRoleGroups',N'/company/role-groups',N'10'),
(N'11003',N'กลุ่มสิทธิ์',N'partnerRoleGroups',N'/partner/role-groups',N'11');
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,ScreenType,CreateDate)
SELECT m.MenuCode,m.ScopeCode,m.MenuName,m.RouteName,m.RoutePath,N'ROLE_GROUP',N'admin_panel_settings',30,1,1,1,1,SYSUTCDATETIME()
FROM @Menus m WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu x WHERE x.MenuCode=m.MenuCode);

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ActionCode,ActionNameTH,IsActive,CreatedDate)
SELECT @ProjectID,m.MenuCode,m.MenuName,a.ActionCode,a.ActionName,1,SYSUTCDATETIME()
FROM @Menus m CROSS JOIN (VALUES(N'VIEW',N'ดูข้อมูล'),(N'CREATE',N'เพิ่ม'),(N'EDIT',N'แก้ไข'),(N'DELETE',N'ลบ')) a(ActionCode,ActionName)
WHERE @ProjectID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADPermission p WHERE p.ProjectID=@ProjectID AND p.ScreenCode=m.MenuCode AND p.ActionCode=a.ActionCode);
GO
