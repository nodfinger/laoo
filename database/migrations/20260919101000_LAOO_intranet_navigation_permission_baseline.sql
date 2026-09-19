/* Core-owned LAOO_INTRANET menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint =
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_INTRANET' AND IsActive = 1);
    IF @ProjectID IS NULL THROW 52950, N'Active LAOO_INTRANET project is required.', 1;

    DECLARE @MenuGroupCode char(2) = N'43';
    IF EXISTS
    (
        SELECT 1
        FROM dbo.TDADMenuGroup
        WHERE MenuGroupCode = @MenuGroupCode
          AND (AudienceType <> N'C' OR MenuGroupName <> N'ระบบ Intranet')
    )
        THROW 52949, N'LAOO_INTRANET MenuGroupCode conflicts with an existing group.', 1;

    UPDATE dbo.TDADMenuGroup
    SET AudienceType = N'C',
        MenuGroupName = N'ระบบ Intranet',
        IconName = N'campaign_outlined',
        SortOrder = 430,
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
            (N'C', @MenuGroupCode, N'ระบบ Intranet', N'campaign_outlined',
             430, 0, 1, SYSUTCDATETIME(), 0, 0);

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
        (N'43001', N'ตั้งค่าระบบ Intranet', 2, N'intranetSettings',
         N'/company/intranet-settings', N'INTRANET_SETTINGS', N'settings_outlined', 10),
        (N'43002', N'เนื้อหา Intranet', 4, N'intranetContent',
         N'/company/intranet-content', N'INTRANET_CONTENT', N'campaign_outlined', 20),
        (N'43003', N'กล่องอนุมัติเนื้อหา Intranet', 3, N'intranetApprovalInbox',
         N'/company/intranet-approvals', N'INTRANET_APPROVAL', N'approval_outlined', 30),
        (N'43004', N'Intranet ของฉัน', 3, N'myIntranet',
         N'/company/my-intranet', N'MY_INTRANET', N'newspaper_outlined', 40),
        (N'43005', N'รายงานและประวัติ Intranet', 3, N'intranetReports',
         N'/company/intranet-reports', N'INTRANET_REPORTS', N'assessment_outlined', 50);

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
        THROW 52951, N'LAOO_INTRANET MenuCode conflicts with existing ScreenType or route.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Menus source
        INNER JOIN dbo.TDADMainMenu target
            ON (target.RouteName = source.RouteName OR target.RoutePath = source.RoutePath)
           AND target.MenuCode <> source.MenuCode
    )
        THROW 52952, N'LAOO_INTRANET RouteName or RoutePath is already used.', 1;

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
        (N'43001', N'VIEW'), (N'43001', N'EDIT'),
        (N'43002', N'VIEW'), (N'43002', N'CREATE'), (N'43002', N'EDIT'), (N'43002', N'DELETE'), (N'43002', N'SUBMIT'), (N'43002', N'CANCEL'), (N'43002', N'PUBLISH'),
        (N'43003', N'VIEW'), (N'43003', N'APPROVE'), (N'43003', N'SELF_APPROVE'),
        (N'43004', N'VIEW'),
        (N'43005', N'VIEW');

    UPDATE target
    SET ScreenNameTH = menu.MenuName,
        ScreenNameEN = menu.FeatureCode,
        ActionNameTH = CASE permission.ActionCode
            WHEN N'VIEW' THEN N'ดูข้อมูล'
            WHEN N'CREATE' THEN N'เพิ่มข้อมูล'
            WHEN N'EDIT' THEN N'แก้ไขข้อมูล'
            WHEN N'DELETE' THEN N'ลบข้อมูล'
            WHEN N'SUBMIT' THEN N'ส่งอนุมัติ'
            WHEN N'CANCEL' THEN N'ยกเลิก'
            WHEN N'PUBLISH' THEN N'เผยแพร่'
            WHEN N'APPROVE' THEN N'อนุมัติ'
            WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง'
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
               WHEN N'SUBMIT' THEN N'ส่งอนุมัติ'
               WHEN N'CANCEL' THEN N'ยกเลิก'
               WHEN N'PUBLISH' THEN N'เผยแพร่'
               WHEN N'APPROVE' THEN N'อนุมัติ'
               WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง'
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