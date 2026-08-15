/* Organization structure baseline. Run against DBTDLaoo after review. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF OBJECT_ID(N'dbo.TDADOrganizationUnit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADOrganizationUnit
    (
        OrgUnitID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADOrganizationUnit PRIMARY KEY,
        CompanyID BIGINT NOT NULL,
        UnitType NVARCHAR(10) NOT NULL,
        ParentOrgUnitID BIGINT NULL,
        ParentOrgUnitKey AS ISNULL(ParentOrgUnitID, CONVERT(BIGINT,0)) PERSISTED,
        UnitCode NVARCHAR(50) NOT NULL,
        NameTH NVARCHAR(200) NOT NULL,
        NameEN NVARCHAR(200) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDADOrganizationUnit_IsActive DEFAULT(1),
        CreateDate DATETIME2(7) NOT NULL CONSTRAINT DF_TDADOrganizationUnit_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy BIGINT NULL,
        UpdateDate DATETIME2(7) NULL,
        UpdateBy BIGINT NULL,
        RowVersion ROWVERSION NOT NULL,
        CONSTRAINT CK_TDADOrganizationUnit_UnitType CHECK (UnitType IN (N'DIV',N'DEP')),
        CONSTRAINT FK_TDADOrganizationUnit_Company FOREIGN KEY (CompanyID) REFERENCES dbo.TDADCompany(CompanyID),
        CONSTRAINT FK_TDADOrganizationUnit_Parent FOREIGN KEY (ParentOrgUnitID) REFERENCES dbo.TDADOrganizationUnit(OrgUnitID)
    );
    CREATE UNIQUE INDEX UX_TDADOrganizationUnit_Code ON dbo.TDADOrganizationUnit(CompanyID, UnitType, ParentOrgUnitKey, UnitCode);
END;
GO

DECLARE @ProjectID BIGINT = (SELECT TOP 1 ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
DECLARE @Actions TABLE(ActionCode NVARCHAR(50) NOT NULL);
INSERT @Actions VALUES (N'VIEW'),(N'CREATE'),(N'EDIT'),(N'DELETE'),(N'CHANGE_STATUS');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ActionCode,ActionNameTH,IsActive,CreatedDate)
SELECT @ProjectID,N'ORGANIZATION_STRUCTURE',N'โครงสร้างองค์กร',A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM @Actions A
WHERE @ProjectID IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ProjectID AND P.ScreenCode=N'ORGANIZATION_STRUCTURE' AND P.ActionCode=A.ActionCode);
GO

IF COL_LENGTH(N'dbo.TDADCompany', N'OrgStructureType') IS NULL
    ALTER TABLE dbo.TDADCompany ADD OrgStructureType INT NOT NULL CONSTRAINT DF_TDADCompany_OrgStructureType DEFAULT(1);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'01005')
BEGIN
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,ScreenType,CreateDate)
    VALUES(N'01005',N'01',NCHAR(0x0E42)+NCHAR(0x0E04)+NCHAR(0x0E23)+NCHAR(0x0E07)+NCHAR(0x0E2A)+NCHAR(0x0E23)+NCHAR(0x0E49)+NCHAR(0x0E32)+NCHAR(0x0E07)+NCHAR(0x0E2D)+NCHAR(0x0E07)+NCHAR(0x0E04)+NCHAR(0x0E4C)+NCHAR(0x0E01)+NCHAR(0x0E23),N'organizationStructure',N'/support/organization-structure',N'ORGANIZATION_STRUCTURE',N'account_tree',50,1,1,1,1,SYSUTCDATETIME());
END;
GO
