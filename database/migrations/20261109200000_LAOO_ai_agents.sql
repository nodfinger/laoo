SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @AI bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_AI' AND IsActive=1);
IF @AI IS NULL THROW 54001, N'Active AI project is required.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'64003')
    THROW 54002, N'Menu 64003 is already in use.', 1;

IF OBJECT_ID(N'dbo.TDADAiAgentCompany', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADAiAgentCompany
    (
        CompanyID bigint NOT NULL,
        AgentCode nvarchar(50) NOT NULL,
        DisplayName nvarchar(100) NOT NULL,
        Greeting nvarchar(500) NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_TDADAiAgentCompany_UpdateDate DEFAULT SYSUTCDATETIME(),
        UpdateBy bigint NULL,
        CONSTRAINT PK_TDADAiAgentCompany PRIMARY KEY (CompanyID, AgentCode)
    );
END;

INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,FeatureCode,CreateDate)
VALUES(N'64003',N'64',N'กำหนด Agent AI',2,N'companyAiAgents',N'/company/ai-agents',N'smart_toy',40,1,1,1,N'AI_ASSISTANT',SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@AI,N'64003',N'64',40,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
VALUES(@AI,N'64003',N'กำหนด Agent AI',N'AI agent settings',N'VIEW',N'ดูข้อมูล',N'View',1),
      (@AI,N'64003',N'กำหนด Agent AI',N'AI agent settings',N'EDIT',N'แก้ไข',N'Edit',1);
