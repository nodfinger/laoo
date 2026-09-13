/* Core-owned navigation and permission bootstrap for LAOO_TIME raw attendance data. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @TimeProjectID bigint =
    (
        SELECT ProjectID FROM dbo.TDADProject
        WHERE ProjectCode = N'LAOO_TIME' AND IsActive = 1
    );
    IF @TimeProjectID IS NULL
        THROW 52770, N'Active LAOO_TIME project is required.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu
        WHERE MenuCode = N'25001'
          AND (ScreenType <> 3
            OR ISNULL(RouteName, N'') <> N'timeAttendanceEvents'
            OR ISNULL(RoutePath, N'') <> N'/company/time-attendance-events')
    )
        THROW 52771, N'Time attendance event MenuCode conflicts with existing ScreenType or route.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu
        WHERE MenuCode <> N'25001'
          AND (RouteName = N'timeAttendanceEvents'
            OR RoutePath = N'/company/time-attendance-events')
    )
        THROW 52772, N'Time attendance event RouteName or RoutePath is already used.', 1;

    UPDATE dbo.TDADMenuGroup
    SET MenuGroupName = N'งานเวลาและการลงเวลา', IsActive = 1,
        UpdateDate = SYSUTCDATETIME()
    WHERE MenuGroupCode = N'25';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode = N'25')
        INSERT dbo.TDADMenuGroup
        (
            AudienceType, MenuGroupCode, MenuGroupName, IconName, SortOrder,
            IsExpandedDefault, IsActive, CreateDate, ShowPermissionPoint, OpenOption
        )
        VALUES
        (
            N'C', N'25', N'งานเวลาและการลงเวลา', N'access_time_outlined', 250,
            0, 1, SYSUTCDATETIME(), 0, 0
        );

    UPDATE dbo.TDADMainMenu
    SET MenuGroupCode = N'25', MenuName = N'ตรวจสอบข้อมูลลงเวลา Raw',
        ScreenType = 3, RouteName = N'timeAttendanceEvents',
        RoutePath = N'/company/time-attendance-events',
        FeatureCode = N'TIME_ATTENDANCE_EVENTS', IconName = N'fact_check_outlined',
        SortOrder = 10, IsVisible = 1, IsFavoriteAllowed = 1, IsActive = 1,
        ShowPermissionPoint = 0, UpdateDate = SYSUTCDATETIME()
    WHERE MenuCode = N'25001';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'25001')
        INSERT dbo.TDADMainMenu
        (
            MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
            FeatureCode, IconName, SortOrder, IsVisible, IsFavoriteAllowed,
            IsActive, CreateDate, ShowPermissionPoint
        )
        VALUES
        (
            N'25001', N'25', N'ตรวจสอบข้อมูลลงเวลา Raw', 3,
            N'timeAttendanceEvents', N'/company/time-attendance-events',
            N'TIME_ATTENDANCE_EVENTS', N'fact_check_outlined', 10, 1, 1,
            1, SYSUTCDATETIME(), 0
        );

    UPDATE dbo.TDADProjectMenuGroup
    SET SortOrder = 1, IsActive = 1, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @TimeProjectID AND MenuGroupCode = N'25';

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenuGroup
        WHERE ProjectID = @TimeProjectID AND MenuGroupCode = N'25'
    )
        INSERT dbo.TDADProjectMenuGroup
            (ProjectID, MenuGroupCode, SortOrder, IsActive, CreateDate)
        VALUES(@TimeProjectID, N'25', 1, 1, SYSUTCDATETIME());

    UPDATE dbo.TDADProjectMenu
    SET MenuGroupCode = N'25', SortOrder = 10, IsActive = 1,
        UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @TimeProjectID AND MenuCode = N'25001';

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenu
        WHERE ProjectID = @TimeProjectID AND MenuCode = N'25001'
    )
        INSERT dbo.TDADProjectMenu
            (ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive, CreateDate)
        VALUES(@TimeProjectID, N'25001', N'25', 10, 1, SYSUTCDATETIME());

    UPDATE dbo.TDADProjectMenu
    SET IsActive = 0, UpdateDate = SYSUTCDATETIME()
    WHERE MenuCode = N'25001' AND ProjectID <> @TimeProjectID AND IsActive = 1;

    UPDATE dbo.TDADPermission
    SET ScreenNameTH = N'ตรวจสอบข้อมูลลงเวลา Raw',
        ScreenNameEN = N'Raw attendance data', ActionNameTH = N'ดูข้อมูล',
        ActionNameEN = N'View', IsActive = 1
    WHERE ProjectID = @TimeProjectID AND ScreenCode = N'25001'
      AND ActionCode = N'VIEW';

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission
        WHERE ProjectID = @TimeProjectID AND ScreenCode = N'25001'
          AND ActionCode = N'VIEW'
    )
        INSERT dbo.TDADPermission
        (
            ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
            ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate
        )
        VALUES
        (
            @TimeProjectID, N'25001', N'ตรวจสอบข้อมูลลงเวลา Raw',
            N'Raw attendance data', N'VIEW', N'ดูข้อมูล', N'View', 1,
            SYSUTCDATETIME()
        );

    UPDATE dbo.TDADPermission
    SET IsActive = 0
    WHERE ProjectID = @TimeProjectID AND ScreenCode = N'25001'
      AND ActionCode <> N'VIEW' AND IsActive = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
