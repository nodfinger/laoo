SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDADProjectMenuGroup', N'U') IS NULL
        THROW 52001, 'dbo.TDADProjectMenuGroup was not found.', 1;
    IF OBJECT_ID(N'dbo.TDADProjectMenu', N'U') IS NULL
        THROW 52002, 'dbo.TDADProjectMenu was not found.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO_VISITOR'
          AND ISNULL(ProjectType,N'')<>N'BUSINESS'
    )
        THROW 52003, 'ProjectCode LAOO_VISITOR is already used by another project type.', 1;

    DECLARE @Groups TABLE
    (
        MenuGroupCode char(2) PRIMARY KEY,
        MenuGroupName nvarchar(150) NOT NULL,
        IconName nvarchar(100) NULL,
        SortOrder int NOT NULL,
        FeatureCode nvarchar(100) NULL
    );

    INSERT @Groups(MenuGroupCode,MenuGroupName,IconName,SortOrder,FeatureCode)
    VALUES
        ('31',N'งานประจำวัน',N'calendar_today_outlined',310,N'VISITOR_DAILY'),
        ('32',N'นัดหมายและอนุมัติ',N'event_available_outlined',320,N'VISITOR_APPOINTMENT'),
        ('33',N'ข้อมูลหลักตามพื้นที่',N'location_on_outlined',330,N'VISITOR_MASTER'),
        ('34',N'รายงานและติดตาม',N'analytics_outlined',340,N'VISITOR_REPORT'),
        ('35',N'การแจ้งเตือน',N'notifications_outlined',350,N'VISITOR_NOTIFICATION'),
        ('36',N'ความปลอดภัย',N'security_outlined',360,N'VISITOR_SECURITY');

    DECLARE @Menus TABLE
    (
        MenuCode char(5) PRIMARY KEY,
        MenuGroupCode char(2) NOT NULL,
        MenuName nvarchar(150) NOT NULL,
        ScreenType int NOT NULL,
        RouteName nvarchar(150) NOT NULL,
        RoutePath nvarchar(300) NOT NULL,
        FeatureCode nvarchar(100) NULL,
        IconName nvarchar(100) NULL,
        SortOrder int NOT NULL,
        IsFavoriteAllowed bit NOT NULL
    );

    INSERT @Menus
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsFavoriteAllowed)
    VALUES
        ('31001','31',N'ภาพรวมการปฏิบัติงาน',3,N'gateDashboard',N'/visitor/gate-dashboard',N'13001',N'layout-dashboard',10,1),
        ('31002','31',N'รับผู้มาติดต่อ',1,N'visitorCheckIn',N'/visitor/check-in',N'13002',N'user-plus',20,1),
        ('31003','31',N'ผู้มาติดต่อภายใน',3,N'visitorInside',N'/visitor/inside',N'13003',N'users',30,1),
        ('31004','31',N'บันทึกผู้มาติดต่อออก',2,N'gateCheckOut',N'/visitor/check-out',N'13004',N'log-out',40,1),
        ('31005','31',N'ประวัติผู้มาติดต่อ',3,N'visitorHistory',N'/visitor/history',N'13005',N'history',50,0),
        ('32001','32',N'นัดหมายล่วงหน้า',1,N'preRegister',N'/visitor/pre-register',N'14001',N'calendar-plus',10,1),
        ('32002','32',N'สถานะการอนุมัติ',3,N'approvalStatus',N'/visitor/approval-status',N'14002',N'clipboard-check',20,1),
        ('32003','32',N'ยืนยันการเข้าพบ',2,N'hostConfirm',N'/visitor/host-confirm',N'14003',N'badge-check',30,1),
        ('33001','33',N'สถานที่ / โซน / ประตู',1,N'siteZoneGate',N'/visitor/site-zone-gate',N'15001',N'map',10,0),
        ('33002','33',N'พื้นที่พักอาศัย',1,N'residentialMaster',N'/visitor/residential',N'15002',N'house',20,0),
        ('33003','33',N'สถานประกอบการ',1,N'corporateMaster',N'/visitor/corporate',N'15003',N'building-2',30,0),
        ('33004','33',N'ข้อมูลหลักทั่วไป',1,N'commonMaster',N'/visitor/common-master',N'15004',N'list-tree',40,0),
        ('34001','34',N'ภาพรวมระบบ',3,N'adminDashboard',N'/visitor/admin-dashboard',N'16001',N'chart-column',10,0),
        ('34002','34',N'รายงานผู้มาติดต่อ',3,N'visitorReports',N'/visitor/reports',N'16002',N'file-chart-column',20,0),
        ('34003','34',N'รายการผิดปกติ',3,N'visitorExceptions',N'/visitor/exceptions',N'16003',N'triangle-alert',30,0),
        ('34004','34',N'ลำดับเหตุการณ์',3,N'visitTimeline',N'/visitor/timeline',N'16004',N'list-ordered',40,0),
        ('35001','35',N'การแจ้งเตือน',3,N'notifications',N'/visitor/notifications',N'17001',N'bell',10,0),
        ('35002','35',N'ประวัติการส่ง',3,N'notificationHistory',N'/visitor/notification-history',N'17002',N'send',20,0),
        ('35003','35',N'ช่องทางการแจ้งเตือน',2,N'notificationChannels',N'/visitor/notification-channels',N'17003',N'radio',30,0),
        ('36001','36',N'บันทึกการตรวจสอบ',3,N'visitorAudit',N'/visitor/audit',N'19001',N'scroll-text',10,0),
        ('36002','36',N'รายการเฝ้าระวัง / ห้ามเข้า',1,N'visitorWatchlist',N'/visitor/watchlist',N'19002',N'user-x',20,0),
        ('36003','36',N'นโยบายเก็บรักษาข้อมูล',2,N'retentionPolicy',N'/visitor/retention-policy',N'19003',N'archive',30,0);

    IF EXISTS
    (
        SELECT 1
        FROM @Groups source
        JOIN dbo.TDADMenuGroup target ON target.MenuGroupCode=source.MenuGroupCode
        WHERE target.MenuGroupName<>source.MenuGroupName
    )
        THROW 52004, 'Visitor MenuGroupCode conflicts with an existing group.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Menus source
        JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
        WHERE ISNULL(target.RouteName,N'')<>source.RouteName
           OR ISNULL(target.RoutePath,N'')<>source.RoutePath
    )
        THROW 52005, 'Visitor MenuCode conflicts with an existing menu.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Menus source
        JOIN dbo.TDADMainMenu target
          ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
         AND target.MenuCode<>source.MenuCode
    )
        THROW 52006, 'A Visitor RouteName or RoutePath is already used by another MenuCode.', 1;

    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR')
    BEGIN
        INSERT dbo.TDADProject
            (ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,
             ProjectType,SortOrder,IconName,IsExpandedDefault)
        VALUES
            (N'LAOO_VISITOR',N'ระบบผู้มาติดต่อ',N'Visitor Management',
             N'ระบบบริหารผู้มาติดต่อ นัดหมาย การเข้าออก และความปลอดภัย',1,SYSDATETIME(),
             N'BUSINESS',40,N'badge_outlined',0);
    END
    ELSE
    BEGIN
        UPDATE dbo.TDADProject
        SET ProjectNameTH=N'ระบบผู้มาติดต่อ',ProjectNameEN=N'Visitor Management',
            DescriptionText=N'ระบบบริหารผู้มาติดต่อ นัดหมาย การเข้าออก และความปลอดภัย',
            ProjectType=N'BUSINESS',SortOrder=40,IconName=N'badge_outlined',
            IsExpandedDefault=0,IsActive=1,UpdateDate=SYSDATETIME()
        WHERE ProjectCode=N'LAOO_VISITOR';
    END;

    UPDATE target
    SET target.MenuGroupName=source.MenuGroupName,target.IconName=source.IconName,
        target.SortOrder=source.SortOrder,target.IsExpandedDefault=0,
        target.FeatureCode=source.FeatureCode,target.UpdateDate=SYSDATETIME()
    FROM dbo.TDADMenuGroup target
    JOIN @Groups source ON source.MenuGroupCode=target.MenuGroupCode;

    INSERT dbo.TDADMenuGroup
        (AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,
         IsActive,CreateDate,ShowPermissionPoint,OpenOption,FeatureCode)
    SELECT N'C',source.MenuGroupCode,source.MenuGroupName,source.IconName,source.SortOrder,0,
           0,SYSDATETIME(),0,0,source.FeatureCode
    FROM @Groups source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMenuGroup target
        WHERE target.MenuGroupCode=source.MenuGroupCode
    );

    UPDATE target
    SET target.MenuGroupCode=source.MenuGroupCode,target.MenuName=source.MenuName,
        target.ScreenType=source.ScreenType,target.RouteName=source.RouteName,
        target.RoutePath=source.RoutePath,target.FeatureCode=source.FeatureCode,
        target.IconName=source.IconName,target.SortOrder=source.SortOrder,
        target.IsVisible=1,target.IsFavoriteAllowed=source.IsFavoriteAllowed,
        target.UpdateDate=SYSDATETIME()
    FROM dbo.TDADMainMenu target
    JOIN @Menus source ON source.MenuCode=target.MenuCode;

    INSERT dbo.TDADMainMenu
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,
         IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    SELECT source.MenuCode,source.MenuGroupCode,source.MenuName,source.ScreenType,
           source.RouteName,source.RoutePath,source.FeatureCode,source.IconName,
           source.SortOrder,1,source.IsFavoriteAllowed,0,SYSDATETIME(),0
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode
    );

    DECLARE @VisitorProjectID bigint=
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR');

    UPDATE target
    SET target.SortOrder=(source.SortOrder-300)/10,target.UpdateDate=SYSDATETIME()
    FROM dbo.TDADProjectMenuGroup target
    JOIN @Groups source ON source.MenuGroupCode=target.MenuGroupCode
    WHERE target.ProjectID=@VisitorProjectID;

    INSERT dbo.TDADProjectMenuGroup
        (ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @VisitorProjectID,source.MenuGroupCode,(source.SortOrder-300)/10,0,SYSDATETIME()
    FROM @Groups source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenuGroup target
        WHERE target.ProjectID=@VisitorProjectID
          AND target.MenuGroupCode=source.MenuGroupCode
    );

    UPDATE target
    SET target.MenuGroupCode=source.MenuGroupCode,target.SortOrder=source.SortOrder,
        target.UpdateDate=SYSDATETIME()
    FROM dbo.TDADProjectMenu target
    JOIN @Menus source ON source.MenuCode=target.MenuCode
    WHERE target.ProjectID=@VisitorProjectID;

    INSERT dbo.TDADProjectMenu
        (ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @VisitorProjectID,source.MenuCode,source.MenuGroupCode,source.SortOrder,0,SYSDATETIME()
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenu target
        WHERE target.ProjectID=@VisitorProjectID AND target.MenuCode=source.MenuCode
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT ProjectCode,ProjectNameTH,ProjectType,SortOrder,IsActive
FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR';

SELECT g.MenuGroupCode,g.MenuGroupName,g.SortOrder,g.IsActive,
       COUNT(m.MenuCode) AS MenuCount
FROM dbo.TDADMenuGroup g
LEFT JOIN dbo.TDADMainMenu m ON m.MenuGroupCode=g.MenuGroupCode
WHERE g.MenuGroupCode IN('31','32','33','34','35','36')
GROUP BY g.MenuGroupCode,g.MenuGroupName,g.SortOrder,g.IsActive
ORDER BY g.MenuGroupCode;
