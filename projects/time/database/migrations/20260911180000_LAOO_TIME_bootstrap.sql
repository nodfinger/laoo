SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDADProjectMenuGroup', N'U') IS NULL
        THROW 52301, 'dbo.TDADProjectMenuGroup was not found.', 1;
    IF OBJECT_ID(N'dbo.TDADProjectMenu', N'U') IS NULL
        THROW 52302, 'dbo.TDADProjectMenu was not found.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO_TIME'
          AND ISNULL(ProjectType,N'')<>N'BUSINESS'
    )
        THROW 52303, 'ProjectCode LAOO_TIME is already used by another project type.', 1;

    DECLARE @Groups TABLE
    (
        MenuGroupCode char(2) PRIMARY KEY,
        MenuGroupName nvarchar(150) NOT NULL,
        IconName nvarchar(100) NULL,
        SortOrder int NOT NULL,
        FeatureCode nvarchar(100) NOT NULL
    );

    INSERT @Groups VALUES
        ('25',N'งานเวลาและการลงเวลา',N'schedule_outlined',250,N'TIME_ATTENDANCE'),
        ('26',N'การลาและคำขอ',N'event_note_outlined',260,N'TIME_REQUEST'),
        ('27',N'กะและตารางทำงาน',N'calendar_month_outlined',270,N'TIME_SCHEDULE'),
        ('28',N'ตั้งค่าระบบเวลา',N'settings_outlined',280,N'TIME_SETUP'),
        ('29',N'ปิดงวดและรายงานเวลา',N'assessment_outlined',290,N'TIME_PERIOD_REPORT'),
        ('30',N'บริการตนเอง',N'person_outline',300,N'TIME_SELF_SERVICE');

    DECLARE @Menus TABLE
    (
        MenuCode char(5) PRIMARY KEY,
        MenuGroupCode char(2) NOT NULL,
        MenuName nvarchar(150) NOT NULL,
        ScreenType int NOT NULL,
        RouteName nvarchar(150) NOT NULL,
        RoutePath nvarchar(300) NOT NULL,
        FeatureCode nvarchar(100) NOT NULL,
        IconName nvarchar(100) NULL,
        SortOrder int NOT NULL
    );

    INSERT @Menus VALUES
        ('28001','28',N'พนักงาน–ลงเวลาทำงาน',2,N'timeEmployeeSettings',
         N'/company/time-employee-settings',N'TIME_EMPLOYEE_SETTINGS',N'badge_outlined',10),
        ('28002','28',N'กำหนดค่าระบบเวลา',2,N'timeSystemSettings',
         N'/company/time-system-settings',N'TIME_SYSTEM_SETTINGS',N'settings_outlined',20);

    IF EXISTS
    (
        SELECT 1 FROM @Groups source
        JOIN dbo.TDADMenuGroup target ON target.MenuGroupCode=source.MenuGroupCode
        WHERE target.MenuGroupName<>source.MenuGroupName
           OR ISNULL(target.FeatureCode,N'')<>source.FeatureCode
    )
        THROW 52304, 'LAOO_TIME MenuGroupCode conflicts with an existing group.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Menus source
        JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
        WHERE ISNULL(target.RouteName,N'')<>source.RouteName
           OR ISNULL(target.RoutePath,N'')<>source.RoutePath
           OR target.ScreenType<>source.ScreenType
    )
        THROW 52305, 'LAOO_TIME MenuCode conflicts with an existing menu.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Menus source
        JOIN dbo.TDADMainMenu target
          ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
         AND target.MenuCode<>source.MenuCode
    )
        THROW 52306, 'A LAOO_TIME RouteName or RoutePath is already used.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME')
    BEGIN
        INSERT dbo.TDADProject
            (ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,
             ProjectType,SortOrder,IconName,IsExpandedDefault)
        VALUES
            (N'LAOO_TIME',N'ระบบบริหารเวลา',N'Time Management',
             N'ระบบบริหารเวลา กะ การลา OT งวดเวลา และบริการตนเอง',1,SYSDATETIME(),
             N'BUSINESS',50,N'schedule_outlined',0);
    END
    ELSE
    BEGIN
        UPDATE dbo.TDADProject
        SET ProjectNameTH=N'ระบบบริหารเวลา',ProjectNameEN=N'Time Management',
            DescriptionText=N'ระบบบริหารเวลา กะ การลา OT งวดเวลา และบริการตนเอง',
            ProjectType=N'BUSINESS',SortOrder=50,IconName=N'schedule_outlined',
            IsExpandedDefault=0,IsActive=1,UpdateDate=SYSDATETIME()
        WHERE ProjectCode=N'LAOO_TIME';
    END;

    UPDATE target
    SET target.MenuGroupName=source.MenuGroupName,target.IconName=source.IconName,
        target.SortOrder=source.SortOrder,target.FeatureCode=source.FeatureCode,
        target.UpdateDate=SYSDATETIME()
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
        target.IsVisible=1,target.IsFavoriteAllowed=1,target.UpdateDate=SYSDATETIME()
    FROM dbo.TDADMainMenu target
    JOIN @Menus source ON source.MenuCode=target.MenuCode;

    INSERT dbo.TDADMainMenu
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,
         IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    SELECT source.MenuCode,source.MenuGroupCode,source.MenuName,source.ScreenType,
           source.RouteName,source.RoutePath,source.FeatureCode,source.IconName,
           source.SortOrder,1,1,0,SYSDATETIME(),0
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode
    );

    DECLARE @TimeProjectID bigint=
        (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME');

    UPDATE target
    SET target.SortOrder=(source.SortOrder-240)/10,target.UpdateDate=SYSDATETIME()
    FROM dbo.TDADProjectMenuGroup target
    JOIN @Groups source ON source.MenuGroupCode=target.MenuGroupCode
    WHERE target.ProjectID=@TimeProjectID;

    INSERT dbo.TDADProjectMenuGroup
        (ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @TimeProjectID,source.MenuGroupCode,(source.SortOrder-240)/10,0,SYSDATETIME()
    FROM @Groups source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenuGroup target
        WHERE target.ProjectID=@TimeProjectID
          AND target.MenuGroupCode=source.MenuGroupCode
    );

    UPDATE target
    SET target.MenuGroupCode=source.MenuGroupCode,target.SortOrder=source.SortOrder,
        target.UpdateDate=SYSDATETIME()
    FROM dbo.TDADProjectMenu target
    JOIN @Menus source ON source.MenuCode=target.MenuCode
    WHERE target.ProjectID=@TimeProjectID;

    INSERT dbo.TDADProjectMenu
        (ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @TimeProjectID,source.MenuCode,source.MenuGroupCode,source.SortOrder,0,SYSDATETIME()
    FROM @Menus source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenu target
        WHERE target.ProjectID=@TimeProjectID AND target.MenuCode=source.MenuCode
    );

    DECLARE @Permissions TABLE
    (
        ScreenCode nvarchar(50),
        ScreenNameTH nvarchar(200),
        ScreenNameEN nvarchar(200),
        ActionCode nvarchar(50),
        ActionNameTH nvarchar(200),
        ActionNameEN nvarchar(200),
        PRIMARY KEY(ScreenCode,ActionCode)
    );

    INSERT @Permissions VALUES
        (N'28001',N'พนักงาน–ลงเวลาทำงาน',N'Employee time settings',N'VIEW',N'ดูข้อมูล',N'View'),
        (N'28001',N'พนักงาน–ลงเวลาทำงาน',N'Employee time settings',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
        (N'28002',N'กำหนดค่าระบบเวลา',N'Time system settings',N'VIEW',N'ดูข้อมูล',N'View'),
        (N'28002',N'กำหนดค่าระบบเวลา',N'Time system settings',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
        (N'28002',N'กำหนดค่าระบบเวลา',N'Time system settings',N'MANAGE_APPROVAL_PROFILE',N'จัดการรูปแบบอนุมัติ',N'Manage approval profile');

    INSERT dbo.TDADPermission
        (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,
         ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @TimeProjectID,P.ScreenCode,P.ScreenNameTH,P.ScreenNameEN,P.ActionCode,
           P.ActionNameTH,P.ActionNameEN,1,SYSDATETIME()
    FROM @Permissions P
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission X
        WHERE X.ProjectID=@TimeProjectID
          AND X.ScreenCode=P.ScreenCode
          AND X.ActionCode=P.ActionCode
    );

    UPDATE X
    SET X.ScreenNameTH=P.ScreenNameTH,X.ScreenNameEN=P.ScreenNameEN,
        X.ActionNameTH=P.ActionNameTH,X.ActionNameEN=P.ActionNameEN,X.IsActive=1
    FROM dbo.TDADPermission X
    JOIN @Permissions P
      ON P.ScreenCode=X.ScreenCode AND P.ActionCode=X.ActionCode
    WHERE X.ProjectID=@TimeProjectID;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT ProjectCode,ProjectNameTH,ProjectType,SortOrder,IsActive
FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME';

SELECT M.MenuCode,M.MenuName,M.ScreenType,M.RouteName,M.IsActive
FROM dbo.TDADMainMenu M
WHERE M.MenuCode IN('28001','28002')
ORDER BY M.MenuCode;
