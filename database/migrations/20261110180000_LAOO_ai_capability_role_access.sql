SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADAiCapabilityRolePolicy', N'U') IS NULL
    CREATE TABLE dbo.TDADAiCapabilityRolePolicy (
        CompanyID bigint NOT NULL,
        CapabilityCode nvarchar(100) NOT NULL,
        UpdatedBy bigint NULL,
        UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TDADAiCapabilityRolePolicy PRIMARY KEY (CompanyID, CapabilityCode)
    );

IF OBJECT_ID(N'dbo.TDADAiCapabilityRoleAccess', N'U') IS NULL
    CREATE TABLE dbo.TDADAiCapabilityRoleAccess (
        CompanyID bigint NOT NULL,
        CapabilityCode nvarchar(100) NOT NULL,
        RoleGroupID bigint NOT NULL,
        CONSTRAINT PK_TDADAiCapabilityRoleAccess PRIMARY KEY (CompanyID, CapabilityCode, RoleGroupID),
        CONSTRAINT FK_TDADAiCapabilityRoleAccess_Policy FOREIGN KEY (CompanyID, CapabilityCode)
            REFERENCES dbo.TDADAiCapabilityRolePolicy(CompanyID, CapabilityCode)
    );

IF NOT EXISTS (SELECT 1 FROM dbo.TDADUserPermissionPointName WHERE MenuCode=N'10008' AND PermissionPointCode=N'MANAGE_AI_CAPABILITY_ACCESS')
    INSERT dbo.TDADUserPermissionPointName
        (MenuCode, PermissionPointCode, PermissionPointName, PermissionPointDescription, SortOrder, IsActive)
    VALUES (N'10008', N'MANAGE_AI_CAPABILITY_ACCESS', N'กำหนดสิทธิ', N'กำหนดกลุ่มสิทธิ์ที่ใช้ความสามารถ AI', 1, 1);

UPDATE dbo.TDADMainMenu SET ShowPermissionPoint=1 WHERE MenuCode='10008' AND ShowPermissionPoint=0;
