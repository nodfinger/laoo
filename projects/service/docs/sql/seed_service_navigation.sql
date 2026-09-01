SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint =
    (
        SELECT TOP (1) ProjectID
        FROM dbo.TDADProject
        WHERE ProjectCode = N'LAOO' AND IsActive = 1
        ORDER BY ProjectID
    );

    IF @ProjectID IS NULL
        THROW 50001, 'ไม่พบ ProjectCode LAOO ที่เปิดใช้งาน', 1;

    DECLARE @Groups TABLE
    (
        SpecGroupCode nvarchar(10) NOT NULL,
        MenuGroupCode char(2) NOT NULL,
        MenuGroupName nvarchar(300) NOT NULL,
        IconName nvarchar(200) NULL,
        SortOrder int NOT NULL
    );

    INSERT INTO @Groups (SpecGroupCode, MenuGroupCode, MenuGroupName, IconName, SortOrder)
    VALUES
        (N'MG101', '14', N'สถานที่และทรัพย์สิน',       N'location_city_outlined', 140),
        (N'MG102', '15', N'รับแจ้งซ่อม',                N'support_agent_outlined', 150),
        (N'MG103', '16', N'บำรุงรักษาตามรอบ',          N'event_repeat_outlined',  160),
        (N'MG104', '17', N'ใบงานและงานช่าง',           N'engineering_outlined',   170),
        (N'MG106', '19', N'สรุปภาพรวมและรายงาน',       N'analytics_outlined',     190),
        (N'MG201', '20', N'บริการตนเองและแจ้งซ่อม',    N'contact_support_outlined', 200);

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADMenuGroup
        WHERE MenuGroupCode = N'08'
          AND MenuGroupName = N'ระบบสินค้า'
          AND IsActive = 1
    )
        THROW 50004, 'ไม่พบกลุ่มเมนูระบบสินค้า รหัส 08 ที่เปิดใช้งาน', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Groups S
        INNER JOIN dbo.TDADMenuGroup T ON T.MenuGroupCode = S.MenuGroupCode
        WHERE T.MenuGroupName <> S.MenuGroupName
    )
        THROW 50002, 'รหัสกลุ่มเมนู 14-20 ชนกับข้อมูลเดิม', 1;

    INSERT INTO dbo.TDADMenuGroup
    (
        AudienceType, MenuGroupCode, MenuGroupName, IconName, SortOrder,
        IsExpandedDefault, IsActive, ShowPermissionPoint, OpenOption, FeatureCode
    )
    SELECT
        N'C', S.MenuGroupCode, S.MenuGroupName, S.IconName, S.SortOrder,
        0, 1, 0, 0, S.SpecGroupCode
    FROM @Groups S
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMenuGroup T
        WHERE T.MenuGroupCode = S.MenuGroupCode
    );

    UPDATE T
    SET T.IconName = S.IconName
    FROM dbo.TDADMenuGroup T
    INNER JOIN @Groups S ON S.MenuGroupCode = T.MenuGroupCode;

    DECLARE @Menus TABLE
    (
        SpecMenuCode nvarchar(10) NOT NULL,
        MenuCode char(5) NOT NULL,
        MenuGroupCode char(2) NOT NULL,
        MenuName nvarchar(300) NOT NULL,
        ScreenType int NOT NULL,
        RouteName nvarchar(300) NOT NULL,
        RoutePath nvarchar(600) NOT NULL,
        IconName nvarchar(200) NULL,
        SortOrder int NOT NULL,
        IsFavoriteAllowed bit NOT NULL
    );

    INSERT INTO @Menus
    (
        SpecMenuCode, MenuCode, MenuGroupCode, MenuName, ScreenType,
        RouteName, RoutePath, IconName, SortOrder, IsFavoriteAllowed
    )
    VALUES
        (N'MN101', '14001', '14', N'ผังสถานที่และห้องพัก',              1, N'assetLocations',       N'/asset/locations',       N'location_city_outlined', 10, 1),
        (N'MN102', '14002', '14', N'ทะเบียนอุปกรณ์และ QR Code',         1, N'assetItems',           N'/asset/items',           N'qr_code_2_outlined',     20, 1),
        (N'MN103', '14003', '14', N'ทะเบียนลูกค้าภายนอก',              1, N'assetCustomers',       N'/asset/customers',       N'contact_page_outlined',  30, 1),

        (N'MN105', '15001', '15', N'รายการแจ้งซ่อมทั้งหมด',             1, N'cmTickets',            N'/cm/tickets',            N'home_repair_service_outlined', 10, 1),
        (N'MN106', '15002', '15', N'จัดการ QR Code แจ้งซ่อม',           1, N'cmQrPortal',           N'/cm/qr-portal',          N'qr_code_scanner_outlined',     20, 1),

        (N'MN107', '16001', '16', N'แผนและรอบเวลา PM',                  1, N'pmPlans',              N'/pm/plans',              N'event_repeat_outlined',   10, 1),
        (N'MN108', '16002', '16', N'รายการตรวจเช็กมาตรฐาน',             1, N'pmChecklists',         N'/pm/checklists',         N'checklist_outlined',      20, 1),
        (N'MN109', '16003', '16', N'ปฏิทินงานบำรุงรักษา',               1, N'pmCalendar',           N'/pm/calendar',           N'calendar_month_outlined', 30, 1),

        (N'MN110', '17001', '17', N'กระดานจ่ายงานช่าง',                 1, N'jobDispatch',          N'/jobs/dispatch',         N'view_kanban_outlined', 10, 1),
        (N'MN111', '17002', '17', N'ทะเบียนใบงานทั้งหมด',               1, N'jobWorkOrders',        N'/jobs/work-orders',      N'assignment_outlined',  20, 1),
        (N'MN112', '17003', '17', N'บันทึกปิดงานและตรวจรับ',            1, N'jobCloseout',          N'/jobs/closeout',         N'task_alt_outlined',    30, 1),

        (N'MN113', '08002', '08', N'รายการอะไหล่และวัสดุ',              1, N'inventoryItems',       N'/inventory/items',       N'inventory_2_outlined', 20, 1),
        (N'MN114', '08003', '08', N'เบิก-จ่ายอะไหล่ตามใบงาน',           1, N'inventoryUsage',       N'/inventory/usage',       N'output_outlined',      30, 1),

        (N'MN115', '19001', '19', N'แดชบอร์ดภาพรวมงานบริการ',           3, N'reportsDashboard',     N'/reports/dashboard',     N'dashboard_outlined',               10, 1),
        (N'MN116', '19002', '19', N'ประวัติการซ่อมและค่าใช้จ่าย',       3, N'reportsHistory',       N'/reports/history',       N'history_outlined',                 20, 1),
        (N'MN117', '19003', '19', N'รายงานผลประเมินความพึงพอใจ',        3, N'reportsSatisfaction',  N'/reports/satisfaction',  N'sentiment_satisfied_alt_outlined', 30, 1),

        (N'MN201', '20001', '20', N'แจ้งซ่อม / ขอใช้บริการ',            1, N'portalRequest',        N'/portal/request',        N'add_circle_outline',       10, 0),
        (N'MN202', '20002', '20', N'ติดตามสถานะงานซ่อม',                1, N'portalTracking',       N'/portal/tracking',       N'track_changes_outlined',  20, 0),
        (N'MN203', '20003', '20', N'ประวัติการซ่อมและค่าบริการ',        1, N'portalHistory',        N'/portal/history',        N'history_outlined',        30, 0),
        (N'MN204', '20004', '20', N'รอบบำรุงรักษาของห้อง',              1, N'portalPmSchedule',     N'/portal/pm-schedule',    N'event_available_outlined',40, 0),
        (N'MN205', '20005', '20', N'ประเมินความพึงพอใจ',                1, N'portalEvaluation',     N'/portal/evaluation',     N'star_outline',           50, 0),
        (N'MN206', '20006', '20', N'แจ้งเรื่องร้องเรียน',               1, N'portalComplaint',      N'/portal/complaint',      N'report_problem_outlined', 60, 0);

    IF EXISTS
    (
        SELECT 1
        FROM @Menus S
        INNER JOIN dbo.TDADMainMenu T ON T.MenuCode = S.MenuCode
        WHERE T.MenuGroupCode <> S.MenuGroupCode OR T.MenuName <> S.MenuName
    )
        THROW 50003, 'รหัสเมนูใหม่ชนกับข้อมูลเดิม', 1;

    INSERT INTO dbo.TDADMainMenu
    (
        MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
        FeatureCode, IconName, SortOrder, IsVisible, IsFavoriteAllowed,
        IsActive, ShowPermissionPoint
    )
    SELECT
        S.MenuCode, S.MenuGroupCode, S.MenuName, S.ScreenType, S.RouteName,
        S.RoutePath, S.SpecMenuCode, S.IconName, S.SortOrder, 1,
        S.IsFavoriteAllowed, 1, 0
    FROM @Menus S
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu T
        WHERE T.MenuCode = S.MenuCode
    );

    UPDATE T
    SET T.IconName = S.IconName
    FROM dbo.TDADMainMenu T
    INNER JOIN @Menus S ON S.MenuCode = T.MenuCode;

    DECLARE @Actions TABLE
    (
        ActionCode nvarchar(100) NOT NULL,
        ActionNameTH nvarchar(400) NOT NULL,
        ActionNameEN nvarchar(400) NOT NULL
    );

    INSERT INTO @Actions (ActionCode, ActionNameTH, ActionNameEN)
    VALUES
        (N'VIEW',   N'ดูข้อมูล', N'View'),
        (N'CREATE', N'เพิ่ม',    N'Create'),
        (N'EDIT',   N'แก้ไข',    N'Edit'),
        (N'DELETE', N'ลบ',       N'Delete');

    INSERT INTO dbo.TDADPermission
    (
        ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
        ActionCode, ActionNameTH, ActionNameEN, IsActive
    )
    SELECT
        @ProjectID, M.MenuCode, M.MenuName, M.RouteName,
        A.ActionCode, A.ActionNameTH, A.ActionNameEN, 1
    FROM @Menus M
    CROSS JOIN @Actions A
    WHERE (M.ScreenType = 1 OR A.ActionCode = N'VIEW')
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.TDADPermission P
          WHERE P.ProjectID = @ProjectID
            AND P.ScreenCode = M.MenuCode
            AND P.ActionCode = A.ActionCode
      );

    -- Company Admin ในโค้ดมีสิทธิ์ผ่าน IsCompanyAdmin อยู่แล้ว ส่วนนี้เปิดให้
    -- Role กลุ่ม Admin ของบริษัทที่มีอยู่ ใช้งานเมนูใหม่ได้ด้วย
    INSERT INTO dbo.TDADRoleGroupPermission
    (
        RoleGroupID, ProjectID, MenuCode, ActionCode, IsAllowed, CreatedBy
    )
    SELECT
        R.RoleGroupID, @ProjectID, M.MenuCode, A.ActionCode, 1,
        N'seed-service-navigation'
    FROM dbo.TDADRoleGroup R
    CROSS JOIN @Menus M
    CROSS JOIN @Actions A
    WHERE R.ProjectID = @ProjectID
      AND R.ScopeType = 'C'
      AND R.IsActive = 1
      AND
      (
          UPPER(LTRIM(RTRIM(R.RoleCode))) IN (N'ADMIN', N'CA')
          OR UPPER(LTRIM(RTRIM(R.RoleNameTH))) = N'ADMIN'
          OR R.RoleNameTH LIKE N'%แอดมิน%'
          OR R.RoleNameTH LIKE N'%ผู้ดูแล%'
      )
      AND (M.ScreenType = 1 OR A.ActionCode = N'VIEW')
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.TDADRoleGroupPermission RP
          WHERE RP.RoleGroupID = R.RoleGroupID
            AND RP.MenuCode = M.MenuCode
            AND RP.ActionCode = A.ActionCode
      );

    COMMIT TRANSACTION;

    SELECT COUNT(*) AS MenuGroupCount
    FROM dbo.TDADMenuGroup
    WHERE MenuGroupCode IN ('14','15','16','17','19','20');

    SELECT COUNT(*) AS MainMenuCount
    FROM dbo.TDADMainMenu
    WHERE MenuCode IN
    (
        '14001','14002','14003','15001','15002','16001','16002','16003',
        '17001','17002','17003','08002','08003','19001','19002','19003',
        '20001','20002','20003','20004','20005','20006'
    );

    SELECT M.MenuGroupCode, M.MenuCode, M.MenuName, M.ScreenType, M.RoutePath,
           M.IsVisible, M.IsActive
    FROM dbo.TDADMainMenu M
    WHERE M.MenuGroupCode IN ('08','14','15','16','17','19','20')
    ORDER BY M.MenuGroupCode, M.SortOrder, M.MenuCode;

    SELECT R.RoleGroupID, R.CompanyID, R.RoleCode, R.RoleNameTH,
           COUNT(*) AS GrantedActionCount
    FROM dbo.TDADRoleGroupPermission RP
    INNER JOIN dbo.TDADRoleGroup R ON R.RoleGroupID = RP.RoleGroupID
    WHERE RP.ProjectID = @ProjectID
      AND RP.MenuCode IN
      (
          '14001','14002','14003','15001','15002','16001','16002','16003',
          '17001','17002','17003','08002','08003','19001','19002','19003',
          '20001','20002','20003','20004','20005','20006'
      )
      AND RP.IsAllowed = 1
    GROUP BY R.RoleGroupID, R.CompanyID, R.RoleCode, R.RoleNameTH
    ORDER BY R.CompanyID, R.RoleGroupID;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
