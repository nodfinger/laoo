/* Core-owned LAOO_POS menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_POS' AND IsActive = 1);
    IF @ProjectID IS NULL THROW 53010, N'Active LAOO_POS project is required.', 1;

    DECLARE @MenuGroupCode char(2) = N'46';
    IF EXISTS (
        SELECT 1 FROM dbo.TDADMenuGroup
        WHERE MenuGroupCode = @MenuGroupCode
          AND (AudienceType <> N'C' OR MenuGroupName <> N'ระบบขายหน้าร้าน')
    ) THROW 53011, N'LAOO_POS MenuGroupCode conflicts with an existing group.', 1;

    UPDATE dbo.TDADMenuGroup
    SET AudienceType = N'C', MenuGroupName = N'ระบบขายหน้าร้าน',
        IconName = N'point_of_sale_outlined', SortOrder = 460,
        IsExpandedDefault = 0, IsActive = 1, ShowPermissionPoint = 0,
        OpenOption = 0, UpdateDate = SYSUTCDATETIME()
    WHERE MenuGroupCode = @MenuGroupCode;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode = @MenuGroupCode)
        INSERT dbo.TDADMenuGroup
            (AudienceType, MenuGroupCode, MenuGroupName, IconName, SortOrder, IsExpandedDefault, IsActive, CreateDate, ShowPermissionPoint, OpenOption)
        VALUES
            (N'C', @MenuGroupCode, N'ระบบขายหน้าร้าน', N'point_of_sale_outlined', 460, 0, 1, SYSUTCDATETIME(), 0, 0);

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
        (N'46001', N'ตั้งค่าระบบ POS', 2, N'posSettings', N'/company/pos-settings', N'POS_SETTINGS', N'settings_outlined', 10),
        (N'46002', N'จุดขายและเครื่องขาย', 1, N'posOutletsTerminals', N'/company/pos-outlets-terminals', N'POS_OUTLETS_TERMINALS', N'point_of_sale_outlined', 20),
        (N'46003', N'สินค้า ราคา และสต็อกตามจุดขาย', 1, N'posOutletItems', N'/company/pos-outlet-items', N'POS_OUTLET_ITEMS', N'inventory_2_outlined', 30),
        (N'46004', N'ขายหน้าร้าน', 4, N'posSales', N'/company/pos-sales', N'POS_SALES', N'receipt_long_outlined', 40),
        (N'46005', N'กะเงินสด', 4, N'posCashShifts', N'/company/pos-cash-shifts', N'POS_CASH_SHIFTS', N'payments_outlined', 50),
        (N'46006', N'คืนและยกเลิกรายการขาย', 4, N'posReturns', N'/company/pos-returns', N'POS_RETURNS', N'keyboard_return_outlined', 60),
        (N'46007', N'รายงาน POS', 3, N'posReports', N'/company/pos-reports', N'POS_REPORTS', N'bar_chart_outlined', 70);

    IF EXISTS (
        SELECT 1 FROM @Menus source
        JOIN dbo.TDADMainMenu target ON target.MenuCode = source.MenuCode
        WHERE target.MenuGroupCode <> @MenuGroupCode
           OR target.ScreenType <> source.ScreenType
           OR ISNULL(target.RouteName, N'') <> source.RouteName
           OR ISNULL(target.RoutePath, N'') <> source.RoutePath
    ) THROW 53012, N'LAOO_POS MenuCode conflicts with existing ScreenType or route.', 1;

    IF EXISTS (
        SELECT 1 FROM @Menus source
        JOIN dbo.TDADMainMenu target
          ON (target.RouteName = source.RouteName OR target.RoutePath = source.RoutePath)
         AND target.MenuCode <> source.MenuCode
    ) THROW 53013, N'LAOO_POS RouteName or RoutePath is already used.', 1;

    UPDATE target
    SET MenuGroupCode = @MenuGroupCode, MenuName = source.MenuName,
        ScreenType = source.ScreenType, RouteName = source.RouteName,
        RoutePath = source.RoutePath, FeatureCode = source.FeatureCode,
        IconName = source.IconName, SortOrder = source.SortOrder,
        IsVisible = 1, IsFavoriteAllowed = 1, IsActive = 1,
        ShowPermissionPoint = 0, UpdateDate = SYSUTCDATETIME()
    FROM dbo.TDADMainMenu target
    JOIN @Menus source ON source.MenuCode = target.MenuCode;

    INSERT dbo.TDADMainMenu
        (MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath, FeatureCode, IconName, SortOrder, IsVisible, IsFavoriteAllowed, IsActive, CreateDate, ShowPermissionPoint)
    SELECT MenuCode, @MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath, FeatureCode, IconName, SortOrder, 1, 1, 1, SYSUTCDATETIME(), 0
    FROM @Menus source
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode = source.MenuCode);

    /* All POS menus remain unavailable until the POS owner delivers each real route, API and migration. */
    UPDATE dbo.TDADProjectMenuGroup
    SET SortOrder = 1, IsActive = 0, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectID = @ProjectID AND MenuGroupCode = @MenuGroupCode;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID = @ProjectID AND MenuGroupCode = @MenuGroupCode)
        INSERT dbo.TDADProjectMenuGroup (ProjectID, MenuGroupCode, SortOrder, IsActive, CreateDate)
        VALUES (@ProjectID, @MenuGroupCode, 1, 0, SYSUTCDATETIME());

    UPDATE target
    SET MenuGroupCode = @MenuGroupCode, SortOrder = source.SortOrder,
        IsActive = 0, UpdateDate = SYSUTCDATETIME()
    FROM dbo.TDADProjectMenu target
    JOIN @Menus source ON source.MenuCode = target.MenuCode
    WHERE target.ProjectID = @ProjectID;

    INSERT dbo.TDADProjectMenu (ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive, CreateDate)
    SELECT @ProjectID, MenuCode, @MenuGroupCode, SortOrder, 0, SYSUTCDATETIME()
    FROM @Menus source
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.TDADProjectMenu target
        WHERE target.ProjectID = @ProjectID AND target.MenuCode = source.MenuCode
    );

    DECLARE @Permissions TABLE
    (
        MenuCode char(5), ActionCode nvarchar(50), ActionNameTH nvarchar(200),
        PRIMARY KEY (MenuCode, ActionCode)
    );

    INSERT @Permissions VALUES
        (N'46001', N'VIEW', N'ดูข้อมูล'), (N'46001', N'EDIT', N'แก้ไขข้อมูล'),
        (N'46002', N'VIEW', N'ดูข้อมูล'), (N'46002', N'CREATE', N'เพิ่มข้อมูล'), (N'46002', N'EDIT', N'แก้ไขข้อมูล'), (N'46002', N'DELETE', N'ลบข้อมูล'),
        (N'46003', N'VIEW', N'ดูข้อมูล'), (N'46003', N'CREATE', N'เพิ่มข้อมูล'), (N'46003', N'EDIT', N'แก้ไขข้อมูล'), (N'46003', N'DELETE', N'ลบข้อมูล'),
        (N'46004', N'VIEW', N'ดูข้อมูล'), (N'46004', N'CREATE', N'เพิ่มข้อมูล'), (N'46004', N'EDIT', N'แก้ไขข้อมูล'), (N'46004', N'DELETE', N'ลบข้อมูล'), (N'46004', N'FINALIZE', N'ชำระเงินและปิดบิล'), (N'46004', N'CANCEL', N'ยกเลิกบิล'), (N'46004', N'DISCOUNT', N'ให้ส่วนลด'), (N'46004', N'PRINT', N'พิมพ์ใบเสร็จ'),
        (N'46005', N'VIEW', N'ดูข้อมูล'), (N'46005', N'CREATE', N'เปิดกะเงินสด'), (N'46005', N'EDIT', N'แก้ไขกะเงินสด'), (N'46005', N'FINALIZE', N'ปิดกะเงินสด'),
        (N'46006', N'VIEW', N'ดูข้อมูล'), (N'46006', N'CREATE', N'สร้างรายการคืนสินค้า'), (N'46006', N'FINALIZE', N'ยืนยันคืนสินค้า'),
        (N'46007', N'VIEW', N'ดูข้อมูล'), (N'46007', N'DOWNLOAD', N'ดาวน์โหลดรายงาน');

    UPDATE target
    SET ScreenNameTH = menu.MenuName, ScreenNameEN = menu.FeatureCode,
        ActionNameTH = source.ActionNameTH, ActionNameEN = source.ActionCode,
        IsActive = 1, ModifiedDate = SYSUTCDATETIME()
    FROM dbo.TDADPermission target
    JOIN @Permissions source ON source.MenuCode = target.ScreenCode AND source.ActionCode = target.ActionCode
    JOIN @Menus menu ON menu.MenuCode = source.MenuCode
    WHERE target.ProjectID = @ProjectID;

    INSERT dbo.TDADPermission
        (ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN, ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate)
    SELECT @ProjectID, source.MenuCode, menu.MenuName, menu.FeatureCode,
           source.ActionCode, source.ActionNameTH, source.ActionCode, 1, SYSUTCDATETIME()
    FROM @Permissions source
    JOIN @Menus menu ON menu.MenuCode = source.MenuCode
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.TDADPermission target
        WHERE target.ProjectID = @ProjectID
          AND target.ScreenCode = source.MenuCode
          AND target.ActionCode = source.ActionCode
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO