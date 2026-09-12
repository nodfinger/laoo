/* Core-owned navigation and permission bootstrap for LAOO_TIME correction workflow. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @TimeProjectID bigint =
    (
        SELECT ProjectID
        FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1
    );
    IF @TimeProjectID IS NULL
        THROW 52760, N'Active LAOO_TIME project is required.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMenuGroup
        WHERE MenuGroupCode IN(N'26',N'28',N'30')
        GROUP BY MenuGroupCode
        HAVING COUNT(*)=1
    )
    OR (SELECT COUNT(*) FROM dbo.TDADMenuGroup WHERE MenuGroupCode IN(N'26',N'28',N'30'))<>3
        THROW 52761, N'Time correction menu groups 26, 28 and 30 are required.', 1;

    DECLARE @Menus TABLE
    (
        MenuCode char(5) PRIMARY KEY,
        MenuGroupCode char(2) NOT NULL,
        MenuName nvarchar(150) NOT NULL,
        ScreenType int NOT NULL,
        RouteName nvarchar(150) NOT NULL,
        RoutePath nvarchar(300) NOT NULL,
        FeatureCode nvarchar(100) NOT NULL,
        IconName nvarchar(100) NOT NULL,
        SortOrder int NOT NULL
    );

    INSERT @Menus VALUES
        (N'26001',N'26',N'คำขอปรับเวลา',4,N'timeCorrectionProxy',N'/company/time-corrections',N'TIME_CORRECTION_PROXY',N'edit_calendar_outlined',10),
        (N'26002',N'26',N'กล่องอนุมัติคำขอเวลา',3,N'timeApprovalInbox',N'/company/time-approval-inbox',N'TIME_APPROVAL_INBOX',N'approval_outlined',20),
        (N'28003',N'28',N'เหตุผลทำแทน',1,N'timeOnBehalfReasons',N'/company/time-on-behalf-reasons',N'TIME_ON_BEHALF_REASON',N'person_add_alt_outlined',30),
        (N'28004',N'28',N'เหตุผลปรับเวลา',1,N'timeAdjustmentReasons',N'/company/time-adjustment-reasons',N'TIME_ADJUSTMENT_REASON',N'rule_outlined',40),
        (N'30001',N'30',N'คำขอปรับเวลาของฉัน',4,N'myTimeCorrections',N'/company/my-time-corrections',N'TIME_CORRECTION_SELF',N'edit_calendar_outlined',10);

    DECLARE @ProjectGroups TABLE(MenuGroupCode char(2) PRIMARY KEY,SortOrder int NOT NULL);
    INSERT @ProjectGroups VALUES(N'26',2),(N'28',4),(N'30',6);

    IF EXISTS
    (
        SELECT 1
        FROM @Menus source
        INNER JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
        WHERE target.ScreenType<>source.ScreenType
           OR ISNULL(target.RouteName,N'')<>source.RouteName
           OR ISNULL(target.RoutePath,N'')<>source.RoutePath
    )
        THROW 52762, N'Time correction MenuCode conflicts with existing ScreenType or route.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Menus source
        INNER JOIN dbo.TDADMainMenu target
          ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
         AND target.MenuCode<>source.MenuCode
    )
        THROW 52763, N'Time correction RouteName or RoutePath is already used.', 1;

    UPDATE target
    SET target.MenuGroupCode=source.MenuGroupCode,
        target.MenuName=source.MenuName,
        target.ScreenType=source.ScreenType,
        target.RouteName=source.RouteName,
        target.RoutePath=source.RoutePath,
        target.FeatureCode=source.FeatureCode,
        target.IconName=source.IconName,
        target.SortOrder=source.SortOrder,
        target.IsVisible=1,
        target.IsFavoriteAllowed=1,
        target.IsActive=1,
        target.ShowPermissionPoint=0,
        target.UpdateDate=SYSUTCDATETIME()
    FROM dbo.TDADMainMenu target
    INNER JOIN @Menus source ON source.MenuCode=target.MenuCode;

    INSERT dbo.TDADMainMenu
    (
        MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,
        IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint
    )
    SELECT source.MenuCode,source.MenuGroupCode,source.MenuName,source.ScreenType,
           source.RouteName,source.RoutePath,source.FeatureCode,source.IconName,
           source.SortOrder,1,1,1,SYSUTCDATETIME(),0
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode
    );

    UPDATE dbo.TDADMenuGroup
    SET IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE MenuGroupCode IN(N'26',N'28',N'30');

    UPDATE target
    SET target.SortOrder=source.SortOrder,
        target.IsActive=1,
        target.UpdateDate=SYSUTCDATETIME()
    FROM dbo.TDADProjectMenuGroup target
    INNER JOIN @ProjectGroups source ON source.MenuGroupCode=target.MenuGroupCode
    WHERE target.ProjectID=@TimeProjectID;

    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @TimeProjectID,source.MenuGroupCode,source.SortOrder,1,SYSUTCDATETIME()
    FROM @ProjectGroups source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenuGroup target
        WHERE target.ProjectID=@TimeProjectID AND target.MenuGroupCode=source.MenuGroupCode
    );

    UPDATE target
    SET target.MenuGroupCode=source.MenuGroupCode,
        target.SortOrder=source.SortOrder,
        target.IsActive=1,
        target.UpdateDate=SYSUTCDATETIME()
    FROM dbo.TDADProjectMenu target
    INNER JOIN @Menus source ON source.MenuCode=target.MenuCode
    WHERE target.ProjectID=@TimeProjectID;

    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @TimeProjectID,source.MenuCode,source.MenuGroupCode,source.SortOrder,1,SYSUTCDATETIME()
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenu target
        WHERE target.ProjectID=@TimeProjectID AND target.MenuCode=source.MenuCode
    );

    DECLARE @Permissions TABLE
    (
        ScreenCode nvarchar(50) NOT NULL,
        ScreenNameTH nvarchar(200) NOT NULL,
        ScreenNameEN nvarchar(200) NOT NULL,
        ActionCode nvarchar(50) NOT NULL,
        ActionNameTH nvarchar(200) NOT NULL,
        ActionNameEN nvarchar(200) NOT NULL,
        PRIMARY KEY(ScreenCode,ActionCode)
    );

    INSERT @Permissions VALUES
        (N'26001',N'คำขอปรับเวลา',N'Time correction request',N'VIEW',N'ดูข้อมูล',N'View'),
        (N'26001',N'คำขอปรับเวลา',N'Time correction request',N'CREATE',N'สร้างคำขอ',N'Create'),
        (N'26001',N'คำขอปรับเวลา',N'Time correction request',N'ACT_ON_BEHALF',N'ทำแทน',N'Act on behalf'),
        (N'26001',N'คำขอปรับเวลา',N'Time correction request',N'APPROVE',N'อนุมัติ',N'Approve'),
        (N'26001',N'คำขอปรับเวลา',N'Time correction request',N'SELF_APPROVE',N'อนุมัติคำขอของตนเอง',N'Self approve'),
        (N'26002',N'กล่องอนุมัติคำขอเวลา',N'Time approval inbox',N'VIEW',N'ดูข้อมูล',N'View'),
        (N'26002',N'กล่องอนุมัติคำขอเวลา',N'Time approval inbox',N'APPROVE',N'อนุมัติ',N'Approve'),
        (N'26002',N'กล่องอนุมัติคำขอเวลา',N'Time approval inbox',N'SELF_APPROVE',N'อนุมัติคำขอของตนเอง',N'Self approve'),
        (N'28003',N'เหตุผลทำแทน',N'On-behalf reasons',N'VIEW',N'ดูข้อมูล',N'View'),
        (N'28003',N'เหตุผลทำแทน',N'On-behalf reasons',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
        (N'28003',N'เหตุผลทำแทน',N'On-behalf reasons',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
        (N'28003',N'เหตุผลทำแทน',N'On-behalf reasons',N'DELETE',N'ลบข้อมูล',N'Delete'),
        (N'28004',N'เหตุผลปรับเวลา',N'Time adjustment reasons',N'VIEW',N'ดูข้อมูล',N'View'),
        (N'28004',N'เหตุผลปรับเวลา',N'Time adjustment reasons',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
        (N'28004',N'เหตุผลปรับเวลา',N'Time adjustment reasons',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
        (N'28004',N'เหตุผลปรับเวลา',N'Time adjustment reasons',N'DELETE',N'ลบข้อมูล',N'Delete'),
        (N'30001',N'คำขอปรับเวลาของฉัน',N'My time corrections',N'VIEW',N'ดูข้อมูล',N'View'),
        (N'30001',N'คำขอปรับเวลาของฉัน',N'My time corrections',N'CREATE',N'สร้างคำขอ',N'Create'),
        (N'30001',N'คำขอปรับเวลาของฉัน',N'My time corrections',N'SUBMIT',N'ส่งคำขอ',N'Submit'),
        (N'30001',N'คำขอปรับเวลาของฉัน',N'My time corrections',N'CANCEL',N'ยกเลิกคำขอ',N'Cancel');

    UPDATE target
    SET target.ScreenNameTH=source.ScreenNameTH,
        target.ScreenNameEN=source.ScreenNameEN,
        target.ActionNameTH=source.ActionNameTH,
        target.ActionNameEN=source.ActionNameEN,
        target.IsActive=1
    FROM dbo.TDADPermission target
    INNER JOIN @Permissions source
      ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode
    WHERE target.ProjectID=@TimeProjectID;

    INSERT dbo.TDADPermission
    (
        ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,
        ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate
    )
    SELECT @TimeProjectID,source.ScreenCode,source.ScreenNameTH,source.ScreenNameEN,
           source.ActionCode,source.ActionNameTH,source.ActionNameEN,1,SYSUTCDATETIME()
    FROM @Permissions source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission target
        WHERE target.ProjectID=@TimeProjectID
          AND target.ScreenCode=source.ScreenCode
          AND target.ActionCode=source.ActionCode
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
