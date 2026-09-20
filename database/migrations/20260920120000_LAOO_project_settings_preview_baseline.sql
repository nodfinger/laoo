SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @SettingsTables TABLE (ProjectCode nvarchar(50) PRIMARY KEY, TableName sysname NOT NULL);
    INSERT @SettingsTables(ProjectCode, TableName) VALUES
      (N'LAOO_SERVICE', N'TDSTCompanySetupSystemService'),
      (N'LAOO_TIME', N'TDSTCompanySetupSystemTime'),
      (N'LAOO_VISITOR', N'TDSTCompanySetupSystemVisitor'),
      (N'LAOO_TRAINING', N'TDSTCompanySetupSystemTraining'),
      (N'LAOO_GATE_PASS', N'TDSTCompanySetupSystemGatePass'),
      (N'LAOO_5S', N'TDSTCompanySetupSystemFiveS'),
      (N'LAOO_SURVEY', N'TDSTCompanySetupSystemSurvey'),
      (N'LAOO_EXPENSE', N'TDSTCompanySetupSystemExpense'),
      (N'LAOO_PROJECT', N'TDSTCompanySetupSystemProjectManagement'),
      (N'LAOO_INTRANET', N'TDSTCompanySetupSystemIntranet'),
      (N'LAOO_VOTE', N'TDSTCompanySetupSystemVote'),
      (N'LAOO_SALES', N'TDSTCompanySetupSystemSales'),
      (N'LAOO_POS', N'TDSTCompanySetupSystemPOS'),
      (N'LAOO_EVALUATION', N'TDSTCompanySetupSystemEvaluation');

    DECLARE @ProjectCode nvarchar(50), @TableName sysname, @CreateSql nvarchar(max);
    DECLARE settings_cursor CURSOR LOCAL FAST_FORWARD FOR
      SELECT ProjectCode, TableName FROM @SettingsTables ORDER BY ProjectCode;
    OPEN settings_cursor;
    FETCH NEXT FROM settings_cursor INTO @ProjectCode, @TableName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=@ProjectCode AND IsActive=1)
            THROW 54100, N'Active project required for Project settings baseline.', 1;
        IF OBJECT_ID(N'dbo.' + @TableName, N'U') IS NULL
        BEGIN
            SET @CreateSql = N'CREATE TABLE dbo.' + QUOTENAME(@TableName) + N'(
                CompanyID bigint NOT NULL,
                ProjectID bigint NOT NULL,
                CreateBy bigint NULL,
                CreateDate datetime2(3) NOT NULL CONSTRAINT ' + QUOTENAME(N'DF_' + @TableName + N'_CreateDate') + N' DEFAULT SYSUTCDATETIME(),
                UpdateBy bigint NULL,
                UpdateDate datetime2(3) NULL,
                CONSTRAINT ' + QUOTENAME(N'PK_' + @TableName) + N' PRIMARY KEY(CompanyID, ProjectID)
            );';
            EXEC sys.sp_executesql @CreateSql;
        END;
        FETCH NEXT FROM settings_cursor INTO @ProjectCode, @TableName;
    END;
    CLOSE settings_cursor;
    DEALLOCATE settings_cursor;

    DECLARE @ServiceGroup char(2)=N'18';
    IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@ServiceGroup AND (AudienceType<>N'C' OR MenuGroupName<>N'��駤���к���ԡ��'))
        THROW 54101, N'Menu group 18 conflicts with the Service settings contract.', 1;
    UPDATE dbo.TDADMenuGroup
       SET AudienceType=N'C', MenuGroupName=N'��駤���к���ԡ��', IconName=N'settings_outlined', SortOrder=180,
           IsExpandedDefault=0, IsActive=1, ShowPermissionPoint=0, OpenOption=0, UpdateDate=SYSUTCDATETIME()
     WHERE MenuGroupCode=@ServiceGroup;
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@ServiceGroup)
      INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
      VALUES(N'C',@ServiceGroup,N'��駤���к���ԡ��',N'settings_outlined',180,0,1,SYSUTCDATETIME(),0,0);

    DECLARE @NewMenus TABLE(
      ProjectCode nvarchar(50) NOT NULL, MenuCode char(5) NOT NULL PRIMARY KEY, MenuGroupCode char(2) NOT NULL,
      MenuName nvarchar(150) NOT NULL, ScreenType int NOT NULL, RouteName nvarchar(150) NOT NULL, RoutePath nvarchar(300) NOT NULL,
      FeatureCode nvarchar(100) NOT NULL, IconName nvarchar(100) NOT NULL, SortOrder int NOT NULL);
    INSERT @NewMenus VALUES
      (N'LAOO_SERVICE',N'18001',N'18',N'��駤���к���ԡ��',2,N'serviceSettings',N'/company/service-settings',N'SERVICE_SETTINGS',N'settings_outlined',10),
      (N'LAOO_MEETING',N'22006',N'22',N'��駤���к���ͧ��Ъ��',2,N'meetingSystemSettings',N'/company/meeting-system-settings',N'MEETING_SETTINGS',N'settings_outlined',60),
      (N'LAOO_VISITOR',N'36004',N'36',N'��駤���к�����ҵԴ���',2,N'visitorSystemSettings',N'/visitor/system-settings',N'VISITOR_SETTINGS',N'settings_outlined',40),
      (N'LAOO_TRAINING',N'37004',N'37',N'��駤���к�ͺ��',2,N'trainingSettings',N'/company/training-settings',N'TRAINING_SETTINGS',N'settings_outlined',40),
      (N'LAOO_5S',N'39010',N'39',N'��駤���к� 5�',2,N'fiveSSettings',N'/company/five-s/settings',N'FIVE_S_SETTINGS',N'settings_outlined',10);

    IF (SELECT COUNT(*) FROM @NewMenus n JOIN dbo.TDADProject p ON p.ProjectCode=n.ProjectCode AND p.IsActive=1) <> (SELECT COUNT(*) FROM @NewMenus)
        THROW 54102, N'An active Project is required for every new settings menu.', 1;
    IF EXISTS(SELECT 1 FROM @NewMenus n JOIN dbo.TDADMainMenu m ON m.MenuCode=n.MenuCode
              WHERE m.MenuGroupCode<>n.MenuGroupCode OR m.ScreenType<>n.ScreenType OR ISNULL(m.RouteName,N'')<>n.RouteName OR ISNULL(m.RoutePath,N'')<>n.RoutePath)
        THROW 54103, N'Settings MenuCode conflicts with an existing menu contract.', 1;
    IF EXISTS(SELECT 1 FROM @NewMenus n JOIN dbo.TDADMainMenu m ON (m.RouteName=n.RouteName OR m.RoutePath=n.RoutePath) AND m.MenuCode<>n.MenuCode)
        THROW 54104, N'Settings route conflicts with an existing menu contract.', 1;

    UPDATE m SET MenuGroupCode=n.MenuGroupCode,MenuName=n.MenuName,ScreenType=n.ScreenType,RouteName=n.RouteName,RoutePath=n.RoutePath,
      FeatureCode=n.FeatureCode,IconName=n.IconName,SortOrder=n.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME()
    FROM dbo.TDADMainMenu m JOIN @NewMenus n ON n.MenuCode=m.MenuCode;
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    SELECT MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0
    FROM @NewMenus n WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu m WHERE m.MenuCode=n.MenuCode);

    DECLARE @ActiveSettings TABLE(ProjectCode nvarchar(50) PRIMARY KEY, MenuCode char(5) NOT NULL, MenuGroupCode char(2) NOT NULL, SortOrder int NOT NULL);
    INSERT @ActiveSettings VALUES
      (N'LAOO_SERVICE',N'18001',N'18',10),(N'LAOO_MEETING',N'22006',N'22',60),(N'LAOO_TIME',N'28002',N'28',20),
      (N'LAOO_VISITOR',N'36004',N'36',40),(N'LAOO_TRAINING',N'37004',N'37',40),(N'LAOO_GATE_PASS',N'38001',N'38',10),
      (N'LAOO_5S',N'39010',N'39',10),(N'LAOO_SURVEY',N'40001',N'40',10),(N'LAOO_EXPENSE',N'41001',N'41',10),
      (N'LAOO_PROJECT',N'42001',N'42',10),(N'LAOO_INTRANET',N'43001',N'43',10),(N'LAOO_VOTE',N'44001',N'44',10),
      (N'LAOO_SALES',N'45001',N'45',10),(N'LAOO_POS',N'46001',N'46',10),(N'LAOO_EVALUATION',N'47001',N'47',10);

    DECLARE @ActiveProjectMenus TABLE(ProjectID bigint NOT NULL, MenuCode char(5) NOT NULL, MenuGroupCode char(2) NOT NULL, SortOrder int NOT NULL, PRIMARY KEY(ProjectID,MenuCode));
    INSERT @ActiveProjectMenus(ProjectID,MenuCode,MenuGroupCode,SortOrder)
    SELECT p.ProjectID,s.MenuCode,s.MenuGroupCode,s.SortOrder FROM @ActiveSettings s JOIN dbo.TDADProject p ON p.ProjectCode=s.ProjectCode AND p.IsActive=1;
    IF (SELECT COUNT(*) FROM @ActiveProjectMenus)<>(SELECT COUNT(*) FROM @ActiveSettings)
      THROW 54105, N'An active Project is required for every settings menu activation.', 1;

    UPDATE pg SET IsActive=1,UpdateDate=SYSUTCDATETIME()
      FROM dbo.TDADProjectMenuGroup pg JOIN (SELECT DISTINCT ProjectID,MenuGroupCode FROM @ActiveProjectMenus) s ON s.ProjectID=pg.ProjectID AND s.MenuGroupCode=pg.MenuGroupCode;
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
      SELECT s.ProjectID,s.MenuGroupCode,1,1,SYSUTCDATETIME()
      FROM (SELECT DISTINCT ProjectID,MenuGroupCode FROM @ActiveProjectMenus) s
      WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup pg WHERE pg.ProjectID=s.ProjectID AND pg.MenuGroupCode=s.MenuGroupCode);

    UPDATE pm SET MenuGroupCode=s.MenuGroupCode,SortOrder=s.SortOrder,IsActive=1,UpdateDate=SYSUTCDATETIME()
      FROM dbo.TDADProjectMenu pm JOIN @ActiveProjectMenus s ON s.ProjectID=pm.ProjectID AND s.MenuCode=pm.MenuCode;
    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
      SELECT s.ProjectID,s.MenuCode,s.MenuGroupCode,s.SortOrder,1,SYSUTCDATETIME() FROM @ActiveProjectMenus s
      WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu pm WHERE pm.ProjectID=s.ProjectID AND pm.MenuCode=s.MenuCode);

    DECLARE @NewPermissions TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
    INSERT @NewPermissions(MenuCode,ActionCode)
    SELECT MenuCode,N'VIEW' FROM @NewMenus UNION ALL SELECT MenuCode,N'EDIT' FROM @NewMenus;
    UPDATE permission SET ScreenNameTH=menu.MenuName,ScreenNameEN=menu.FeatureCode,ActionNameTH=np.ActionCode,ActionNameEN=np.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME()
      FROM dbo.TDADPermission permission JOIN @NewPermissions np ON np.MenuCode=permission.ScreenCode AND np.ActionCode=permission.ActionCode
      JOIN @NewMenus menu ON menu.MenuCode=np.MenuCode JOIN dbo.TDADProject project ON project.ProjectCode=menu.ProjectCode AND project.ProjectID=permission.ProjectID;
    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
      SELECT project.ProjectID,np.MenuCode,menu.MenuName,menu.FeatureCode,np.ActionCode,np.ActionCode,np.ActionCode,1,SYSUTCDATETIME()
      FROM @NewPermissions np JOIN @NewMenus menu ON menu.MenuCode=np.MenuCode JOIN dbo.TDADProject project ON project.ProjectCode=menu.ProjectCode AND project.IsActive=1
      WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission permission WHERE permission.ProjectID=project.ProjectID AND permission.ScreenCode=np.MenuCode AND permission.ActionCode=np.ActionCode);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
