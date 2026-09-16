/* Core-owned LAOO_5S navigation and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint =
    (
        SELECT ProjectID FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO_5S' AND IsActive=1
    );
    IF @ProjectID IS NULL
        THROW 52910, N'Active LAOO_5S project is required.', 1;

    DECLARE @MenuGroupCode char(2) = N'39';
    UPDATE dbo.TDADMenuGroup
    SET AudienceType=N'C', MenuGroupName=N'ระบบตรวจ 5ส',
        IconName=N'fact_check_outlined', SortOrder=390, IsExpandedDefault=0,
        IsActive=1, ShowPermissionPoint=0, OpenOption=0, UpdateDate=SYSUTCDATETIME()
    WHERE MenuGroupCode=@MenuGroupCode;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode)
        INSERT dbo.TDADMenuGroup
        (
            AudienceType, MenuGroupCode, MenuGroupName, IconName, SortOrder,
            IsExpandedDefault, IsActive, CreateDate, ShowPermissionPoint, OpenOption
        )
        VALUES
        (N'C', @MenuGroupCode, N'ระบบตรวจ 5ส', N'fact_check_outlined', 390,
         0, 1, SYSUTCDATETIME(), 0, 0);

    DECLARE @Menus TABLE
    (
        MenuCode char(5) PRIMARY KEY, MenuName nvarchar(150) NOT NULL,
        ScreenType int NOT NULL, RouteName nvarchar(150) NOT NULL,
        RoutePath nvarchar(300) NOT NULL, FeatureCode nvarchar(100) NOT NULL,
        IconName nvarchar(100) NOT NULL, SortOrder int NOT NULL
    );
    INSERT @Menus VALUES
        (N'39001', N'พื้นที่ตรวจ 5ส', 1, N'fiveSInspectionAreas', N'/company/five-s/inspection-areas', N'FIVE_S_INSPECTION_AREAS', N'location_on_outlined', 10),
        (N'39002', N'Template และเกณฑ์คะแนน 5ส', 1, N'fiveSTemplates', N'/company/five-s/templates', N'FIVE_S_TEMPLATES', N'checklist_outlined', 20),
        (N'39003', N'ทีมตรวจ', 1, N'fiveSInspectionTeams', N'/company/five-s/inspection-teams', N'FIVE_S_INSPECTION_TEAMS', N'groups_outlined', 30),
        (N'39004', N'แผนและรอบตรวจ', 1, N'fiveSInspectionPlans', N'/company/five-s/inspection-plans', N'FIVE_S_INSPECTION_PLANS', N'calendar_month_outlined', 40),
        (N'39005', N'ตรวจ 5ส', 4, N'fiveSInspections', N'/company/five-s/inspections', N'FIVE_S_INSPECTIONS', N'fact_check_outlined', 50),
        (N'39006', N'ยืนยันผลตรวจ', 2, N'fiveSInspectionConfirmations', N'/company/five-s/inspection-confirmations', N'FIVE_S_INSPECTION_CONFIRMATIONS', N'approval_outlined', 60),
        (N'39007', N'ข้อบกพร่องและการแก้ไข', 2, N'fiveSFindings', N'/company/five-s/findings', N'FIVE_S_FINDINGS', N'build_circle_outlined', 70),
        (N'39008', N'ประวัติผลตรวจ', 3, N'fiveSInspectionHistory', N'/company/five-s/inspection-history', N'FIVE_S_INSPECTION_HISTORY', N'history_outlined', 80),
        (N'39009', N'รายงานคะแนนและข้อบกพร่องค้าง', 3, N'fiveSReports', N'/company/five-s/reports', N'FIVE_S_REPORTS', N'assessment_outlined', 90);

    IF EXISTS
    (
        SELECT 1 FROM @Menus source
        INNER JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
        WHERE target.ScreenType<>source.ScreenType
           OR ISNULL(target.RouteName,N'')<>source.RouteName
           OR ISNULL(target.RoutePath,N'')<>source.RoutePath
    )
        THROW 52911, N'LAOO_5S MenuCode conflicts with existing ScreenType or route.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Menus source
        INNER JOIN dbo.TDADMainMenu target
          ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
         AND target.MenuCode<>source.MenuCode
    )
        THROW 52912, N'LAOO_5S RouteName or RoutePath is already used.', 1;

    UPDATE target
    SET target.MenuGroupCode=@MenuGroupCode, target.MenuName=source.MenuName,
        target.ScreenType=source.ScreenType, target.RouteName=source.RouteName,
        target.RoutePath=source.RoutePath, target.FeatureCode=source.FeatureCode,
        target.IconName=source.IconName, target.SortOrder=source.SortOrder,
        target.IsVisible=1, target.IsFavoriteAllowed=1, target.IsActive=1,
        target.ShowPermissionPoint=0, target.UpdateDate=SYSUTCDATETIME()
    FROM dbo.TDADMainMenu target INNER JOIN @Menus source ON source.MenuCode=target.MenuCode;

    INSERT dbo.TDADMainMenu
    (
        MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
        FeatureCode, IconName, SortOrder, IsVisible, IsFavoriteAllowed,
        IsActive, CreateDate, ShowPermissionPoint
    )
    SELECT MenuCode, @MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
           FeatureCode, IconName, SortOrder, 1, 1, 1, SYSUTCDATETIME(), 0
    FROM @Menus source
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode);

    /* Keep unavailable until project routes, API and migrations are implemented. */
    UPDATE dbo.TDADProjectMenuGroup
    SET SortOrder=1, IsActive=0, UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenuGroup
        WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode
    )
        INSERT dbo.TDADProjectMenuGroup(ProjectID, MenuGroupCode, SortOrder, IsActive, CreateDate)
        VALUES(@ProjectID, @MenuGroupCode, 1, 0, SYSUTCDATETIME());

    UPDATE target
    SET MenuGroupCode=@MenuGroupCode, SortOrder=source.SortOrder,
        IsActive=0, UpdateDate=SYSUTCDATETIME()
    FROM dbo.TDADProjectMenu target INNER JOIN @Menus source ON source.MenuCode=target.MenuCode
    WHERE target.ProjectID=@ProjectID;
    INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive, CreateDate)
    SELECT @ProjectID, MenuCode, @MenuGroupCode, SortOrder, 0, SYSUTCDATETIME()
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenu target
        WHERE target.ProjectID=@ProjectID AND target.MenuCode=source.MenuCode
    );

    DECLARE @Permissions TABLE(MenuCode char(5), ActionCode nvarchar(50), PRIMARY KEY(MenuCode, ActionCode));
    INSERT @Permissions VALUES
        (N'39001',N'VIEW'),(N'39001',N'CREATE'),(N'39001',N'EDIT'),(N'39001',N'DELETE'),
        (N'39002',N'VIEW'),(N'39002',N'CREATE'),(N'39002',N'EDIT'),(N'39002',N'DELETE'),
        (N'39003',N'VIEW'),(N'39003',N'CREATE'),(N'39003',N'EDIT'),(N'39003',N'DELETE'),
        (N'39004',N'VIEW'),(N'39004',N'CREATE'),(N'39004',N'EDIT'),(N'39004',N'DELETE'),
        (N'39005',N'VIEW'),(N'39005',N'CREATE'),(N'39005',N'EDIT'),(N'39005',N'DELETE'),(N'39005',N'SUBMIT'),(N'39005',N'ACT_ON_BEHALF'),
        (N'39006',N'VIEW'),(N'39006',N'APPROVE'),(N'39006',N'SELF_APPROVE'),
        (N'39007',N'VIEW'),(N'39007',N'EDIT'),(N'39007',N'ASSIGN'),(N'39007',N'CONFIRM'),
        (N'39008',N'VIEW'),(N'39009',N'VIEW');

    UPDATE target
    SET ScreenNameTH=menu.MenuName, ScreenNameEN=menu.FeatureCode,
        ActionNameTH=CASE source.ActionCode
            WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล'
            WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล'
            WHEN N'SUBMIT' THEN N'ส่งตรวจ' WHEN N'ACT_ON_BEHALF' THEN N'ทำรายการแทน'
            WHEN N'APPROVE' THEN N'ยืนยันผลตรวจ' WHEN N'SELF_APPROVE' THEN N'ยืนยันรายการของตนเอง'
            WHEN N'ASSIGN' THEN N'มอบหมาย' WHEN N'CONFIRM' THEN N'ยืนยันปิด' END,
        ActionNameEN=source.ActionCode, IsActive=1, ModifiedDate=SYSUTCDATETIME()
    FROM dbo.TDADPermission target
    INNER JOIN @Permissions source ON source.MenuCode=target.ScreenCode AND source.ActionCode=target.ActionCode
    INNER JOIN @Menus menu ON menu.MenuCode=source.MenuCode
    WHERE target.ProjectID=@ProjectID;

    INSERT dbo.TDADPermission
    (
        ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN, ActionCode,
        ActionNameTH, ActionNameEN, IsActive, CreatedDate
    )
    SELECT @ProjectID, source.MenuCode, menu.MenuName, menu.FeatureCode,
           source.ActionCode,
           CASE source.ActionCode
               WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล'
               WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล'
               WHEN N'SUBMIT' THEN N'ส่งตรวจ' WHEN N'ACT_ON_BEHALF' THEN N'ทำรายการแทน'
               WHEN N'APPROVE' THEN N'ยืนยันผลตรวจ' WHEN N'SELF_APPROVE' THEN N'ยืนยันรายการของตนเอง'
               WHEN N'ASSIGN' THEN N'มอบหมาย' WHEN N'CONFIRM' THEN N'ยืนยันปิด' END,
           source.ActionCode, 1, SYSUTCDATETIME()
    FROM @Permissions source INNER JOIN @Menus menu ON menu.MenuCode=source.MenuCode
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission target
        WHERE target.ProjectID=@ProjectID
          AND target.ScreenCode=source.MenuCode AND target.ActionCode=source.ActionCode
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
