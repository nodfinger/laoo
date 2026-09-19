/* Core-owned LAOO_PROJECT menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint =
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_PROJECT' AND IsActive = 1);
    IF @ProjectID IS NULL THROW 52940, N'Active LAOO_PROJECT project is required.', 1;

    DECLARE @MenuGroupCode char(2) = N'42';
    IF EXISTS
    (
        SELECT 1
        FROM dbo.TDADMenuGroup
        WHERE MenuGroupCode = @MenuGroupCode
          AND (AudienceType <> N'C' OR MenuGroupName <> N'ระบบบริหารโครงการ')
    )
        THROW 52939, N'LAOO_PROJECT MenuGroupCode conflicts with an existing group.', 1;

    UPDATE dbo.TDADMenuGroup
    SET AudienceType = N'C',
        MenuGroupName = N'ระบบบริหารโครงการ',
        IconName = N'folder_managed_outlined',
        SortOrder = 420,
        IsExpandedDefault = 0,
        IsActive = 1,
        ShowPermissionPoint = 0,
        OpenOption = 0,
        UpdateDate = SYSUTCDATETIME()
    WHERE MenuGroupCode = @MenuGroupCode;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode = @MenuGroupCode)
        INSERT dbo.TDADMenuGroup
            (AudienceType, MenuGroupCode, MenuGroupName, IconName, SortOrder,
             IsExpandedDefault, IsActive, CreateDate, ShowPermissionPoint, OpenOption)
        VALUES
            (N'C', @MenuGroupCode, N'ระบบบริหารโครงการ', N'folder_managed_outlined',
             420, 0, 1, SYSUTCDATETIME(), 0, 0);

    DECLARE @Menus TABLE
    (
        MenuCode char(5) PRIMARY KEY,
        MenuName nvarchar(150),
        ScreenType int,
        RouteName nvarchar(150),
        RoutePath nvarchar(300),
        FeatureCode nvarchar(100),
        IconName nvarchar(100),
        SortOrder int
    );
    INSERT @Menus VALUES
        (N'42001', N'ตั้งค่าระบบบริหารโครงการ', 2, N'projectSettings',
         N'/company/project-settings', N'PROJECT_SETTINGS', N'settings_outlined', 10),
        (N'42002', N'หมวดงบประมาณโครงการ', 1, N'projectBudgetCategories',
         N'/company/project-budget-categories', N'PROJECT_BUDGET_CATEGORIES', N'category_outlined', 20),
        (N'42003', N'โครงการ', 4, N'projects',
         N'/company/projects', N'PROJECTS', N'folder_managed_outlined', 30),
        (N'42004', N'งานของฉัน', 2, N'myProjectTasks',
         N'/company/my-project-tasks', N'MY_PROJECT_TASKS', N'assignment_ind_outlined', 40),
        (N'42005', N'รายงานโครงการ', 3, N'projectReports',
         N'/company/project-reports', N'PROJECT_REPORTS', N'assessment_outlined', 50);

    IF EXISTS
    (
        SELECT 1
        FROM @Menus source
        INNER JOIN dbo.TDADMainMenu target ON target.MenuCode = source.MenuCode
        WHERE target.MenuGroupCode <> @MenuGroupCode
           OR target.ScreenType <> source.ScreenType
           OR ISNULL(target.RouteName, N'') <> source.RouteName
           OR ISNULL(target.RoutePath, N'') <> source.RoutePath
    )
        THROW 52941, N'LAOO_PROJECT MenuCode conflicts with existing ScreenType or route.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Menus source
        INNER JOIN dbo.TDADMainMenu target
            ON (target.RouteName = source.RouteName OR target.RoutePath = source.RoutePath)
           AND target.MenuCode <> source.MenuCode
    )
        THROW 52942, N'LAOO_PROJECT RouteName or RoutePath is already used.', 1;

    UPDATE target
    SET MenuGroupCode = @MenuGroupCode,
        MenuName = source.MenuName,
        ScreenType = source.ScreenType,
        RouteName = source.RouteName,
        RoutePath = source.RoutePath,
        FeatureCode = source.FeatureCode,
        IconName = source.IconName,
        SortOrder = source.SortOrder,
        IsVisible = 1,
        IsFavoriteAllowed = 1,
        IsActive = 1,
        ShowPermissionPoint = 0,
        UpdateDate = SYSUTCDATETIME()
    FROM dbo.TDADMainMenu target
    INNER JOIN @Menus source ON source.MenuCode = target.MenuCode;

    INSERT dbo.TDADMainMenu
        (MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
         FeatureCode, IconName, SortOrder, IsVisible, IsFavoriteAllowed,
         IsActive, CreateDate, ShowPermissionPoint)
    SELECT MenuCode, @MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
           FeatureCode, IconName, SortOrder, 1, 1, 1, SYSUTCDATETIME(), 0
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode = source.MenuCode
    );

    /* Menus remain unavailable until real routes, API and project migrations exist. */
    UPDATE dbo.TDADProjectMenuGroup
    SET SortOrder = 1, IsActive = 0, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @ProjectID AND MenuGroupCode = @MenuGroupCode;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenuGroup
        WHERE ProjectID = @ProjectID AND MenuGroupCode = @MenuGroupCode
    )
        INSERT dbo.TDADProjectMenuGroup
            (ProjectID, MenuGroupCode, SortOrder, IsActive, CreateDate)
        VALUES (@ProjectID, @MenuGroupCode, 1, 0, SYSUTCDATETIME());

    UPDATE target
    SET MenuGroupCode = @MenuGroupCode,
        SortOrder = source.SortOrder,
        IsActive = 0,
        UpdateDate = SYSUTCDATETIME()
    FROM dbo.TDADProjectMenu target
    INNER JOIN @Menus source ON source.MenuCode = target.MenuCode
    WHERE target.ProjectID = @ProjectID;

    INSERT dbo.TDADProjectMenu
        (ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive, CreateDate)
    SELECT @ProjectID, MenuCode, @MenuGroupCode, SortOrder, 0, SYSUTCDATETIME()
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADProjectMenu target
        WHERE target.ProjectID = @ProjectID AND target.MenuCode = source.MenuCode
    );

    DECLARE @Permissions TABLE
    (
        MenuCode char(5),
        ActionCode nvarchar(50),
        PRIMARY KEY (MenuCode, ActionCode)
    );
    INSERT @Permissions VALUES
        (N'42001', N'VIEW'), (N'42001', N'EDIT'),
        (N'42002', N'VIEW'), (N'42002', N'CREATE'), (N'42002', N'EDIT'), (N'42002', N'DELETE'),
        (N'42003', N'VIEW'), (N'42003', N'CREATE'), (N'42003', N'EDIT'), (N'42003', N'DELETE'), (N'42003', N'CLOSE'),
        (N'42004', N'VIEW'), (N'42004', N'EDIT'),
        (N'42005', N'VIEW');

    UPDATE target
    SET ScreenNameTH = menu.MenuName,
        ScreenNameEN = menu.FeatureCode,
        ActionNameTH = CASE permission.ActionCode
            WHEN N'VIEW' THEN N'ดูข้อมูล'
            WHEN N'CREATE' THEN N'เพิ่มข้อมูล'
            WHEN N'EDIT' THEN N'แก้ไขข้อมูล'
            WHEN N'DELETE' THEN N'ลบข้อมูล'
            WHEN N'CLOSE' THEN N'ปิดโครงการ'
        END,
        ActionNameEN = permission.ActionCode,
        IsActive = 1,
        ModifiedDate = SYSUTCDATETIME()
    FROM dbo.TDADPermission target
    INNER JOIN @Permissions permission
        ON permission.MenuCode = target.ScreenCode
       AND permission.ActionCode = target.ActionCode
    INNER JOIN @Menus menu ON menu.MenuCode = permission.MenuCode
    WHERE target.ProjectID = @ProjectID;

    INSERT dbo.TDADPermission
        (ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN, ActionCode,
         ActionNameTH, ActionNameEN, IsActive, CreatedDate)
    SELECT @ProjectID, permission.MenuCode, menu.MenuName, menu.FeatureCode,
           permission.ActionCode,
           CASE permission.ActionCode
               WHEN N'VIEW' THEN N'ดูข้อมูล'
               WHEN N'CREATE' THEN N'เพิ่มข้อมูล'
               WHEN N'EDIT' THEN N'แก้ไขข้อมูล'
               WHEN N'DELETE' THEN N'ลบข้อมูล'
               WHEN N'CLOSE' THEN N'ปิดโครงการ'
           END,
           permission.ActionCode, 1, SYSUTCDATETIME()
    FROM @Permissions permission
    INNER JOIN @Menus menu ON menu.MenuCode = permission.MenuCode
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADPermission target
        WHERE target.ProjectID = @ProjectID
          AND target.ScreenCode = permission.MenuCode
          AND target.ActionCode = permission.ActionCode
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
