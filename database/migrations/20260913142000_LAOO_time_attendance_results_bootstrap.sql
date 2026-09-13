/* Core-owned navigation and permission bootstrap for LAOO_TIME daily attendance results. */
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
        THROW 52780, N'Active LAOO_TIME project is required.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu
        WHERE MenuCode = N'25002'
          AND (ScreenType <> 3
            OR ISNULL(RouteName, N'') <> N'timeAttendanceResults'
            OR ISNULL(RoutePath, N'') <> N'/company/time-attendance-results')
    )
        THROW 52781, N'Time attendance results MenuCode conflicts with existing ScreenType or route.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu
        WHERE MenuCode <> N'25002'
          AND (RouteName = N'timeAttendanceResults'
            OR RoutePath = N'/company/time-attendance-results')
    )
        THROW 52782, N'Time attendance results RouteName or RoutePath is already used.', 1;

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
    SET MenuGroupCode = N'25', MenuName = N'ผลการลงเวลารายวัน',
        ScreenType = 3, RouteName = N'timeAttendanceResults',
        RoutePath = N'/company/time-attendance-results',
        FeatureCode = N'TIME_ATTENDANCE_RESULTS', IconName = N'analytics_outlined',
        SortOrder = 20, IsVisible = 1, IsFavoriteAllowed = 1, IsActive = 1,
        ShowPermissionPoint = 0, UpdateDate = SYSUTCDATETIME()
    WHERE MenuCode = N'25002';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'25002')
        INSERT dbo.TDADMainMenu
        (
            MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
            FeatureCode, IconName, SortOrder, IsVisible, IsFavoriteAllowed,
            IsActive, CreateDate, ShowPermissionPoint
        )
        VALUES
        (
            N'25002', N'25', N'ผลการลงเวลารายวัน', 3,
            N'timeAttendanceResults', N'/company/time-attendance-results',
            N'TIME_ATTENDANCE_RESULTS', N'analytics_outlined', 20, 1, 1,
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
    SET MenuGroupCode = N'25', SortOrder = 20, IsActive = 1,
        UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @TimeProjectID AND MenuCode = N'25002';

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADProjectMenu
        WHERE ProjectID = @TimeProjectID AND MenuCode = N'25002'
    )
        INSERT dbo.TDADProjectMenu
            (ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive, CreateDate)
        VALUES(@TimeProjectID, N'25002', N'25', 20, 1, SYSUTCDATETIME());

    UPDATE dbo.TDADProjectMenu
    SET IsActive = 0, UpdateDate = SYSUTCDATETIME()
    WHERE MenuCode = N'25002' AND ProjectID <> @TimeProjectID AND IsActive = 1;

    UPDATE dbo.TDADPermission
    SET ScreenNameTH = N'ผลการลงเวลารายวัน',
        ScreenNameEN = N'Daily attendance results', ActionNameTH = N'ดูข้อมูล',
        ActionNameEN = N'View', IsActive = 1
    WHERE ProjectID = @TimeProjectID AND ScreenCode = N'25002'
      AND ActionCode = N'VIEW';

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission
        WHERE ProjectID = @TimeProjectID AND ScreenCode = N'25002'
          AND ActionCode = N'VIEW'
    )
        INSERT dbo.TDADPermission
        (
            ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
            ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate
        )
        VALUES
        (
            @TimeProjectID, N'25002', N'ผลการลงเวลารายวัน',
            N'Daily attendance results', N'VIEW', N'ดูข้อมูล', N'View', 1,
            SYSUTCDATETIME()
        );

    UPDATE dbo.TDADPermission
    SET IsActive = 0
    WHERE ProjectID = @TimeProjectID AND ScreenCode = N'25002'
      AND ActionCode <> N'VIEW' AND IsActive = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
