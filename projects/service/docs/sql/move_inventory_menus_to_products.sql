SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADMenuGroup
        WHERE MenuGroupCode = N'08'
          AND MenuGroupName = N'ระบบสินค้า'
          AND IsActive = 1
    )
        THROW 50001, 'ไม่พบกลุ่มเมนูระบบสินค้า รหัส 08 ที่เปิดใช้งาน', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TDADMainMenu
        WHERE MenuCode IN (N'08002', N'08003')
          AND RouteName NOT IN (N'inventoryItems', N'inventoryUsage')
    )
        THROW 50002, 'รหัสเมนู 08002 หรือ 08003 ถูกใช้งานโดยเมนูอื่น', 1;

    UPDATE dbo.TDADPermission
    SET ScreenCode = CASE ScreenCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDADRoleGroupPermission
    SET MenuCode = CASE MenuCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE MenuCode IN (N'18001', N'18002');

    UPDATE dbo.TDADUserFavorite
    SET MenuCode = CASE MenuCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE MenuCode IN (N'18001', N'18002');

    UPDATE dbo.TDADUserPermissionPoint
    SET MenuCode = CASE MenuCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE MenuCode IN (N'18001', N'18002');

    UPDATE dbo.TDADUserPermissionPointName
    SET MenuCode = CASE MenuCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE MenuCode IN (N'18001', N'18002');

    UPDATE dbo.TDADAuditLog
    SET ScreenCode = CASE ScreenCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDSTMDSystem
    SET MenuCode = CASE MenuCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE MenuCode IN (N'18001', N'18002');

    UPDATE dbo.TDSTScreen
    SET MenuCode = CASE MenuCode
            WHEN N'18001' THEN N'08002'
            WHEN N'18002' THEN N'08003'
            ELSE MenuCode
        END,
        ScreenCode = CASE ScreenCode
            WHEN N'18001' THEN N'08002'
            WHEN N'18002' THEN N'08003'
            ELSE ScreenCode
        END
    WHERE MenuCode IN (N'18001', N'18002')
       OR ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDSTScreenAPI
    SET ScreenCode = CASE ScreenCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDSTScreenDartFile
    SET MenuCode = CASE MenuCode
            WHEN N'18001' THEN N'08002'
            WHEN N'18002' THEN N'08003'
            ELSE MenuCode
        END,
        ScreenCode = CASE ScreenCode
            WHEN N'18001' THEN N'08002'
            WHEN N'18002' THEN N'08003'
            ELSE ScreenCode
        END
    WHERE MenuCode IN (N'18001', N'18002')
       OR ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDSTScreenField
    SET ScreenCode = CASE ScreenCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDSTScreenPermission
    SET ScreenCode = CASE ScreenCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDSTScreenTable
    SET ScreenCode = CASE ScreenCode
        WHEN N'18001' THEN N'08002'
        WHEN N'18002' THEN N'08003'
    END
    WHERE ScreenCode IN (N'18001', N'18002');

    UPDATE dbo.TDADMainMenu
    SET MenuCode = N'08002',
        MenuGroupCode = N'08',
        MenuName = N'รายการอะไหล่และวัสดุ',
        IconName = N'inventory_2_outlined',
        SortOrder = 20
    WHERE MenuCode = N'18001';

    UPDATE dbo.TDADMainMenu
    SET MenuCode = N'08003',
        MenuGroupCode = N'08',
        MenuName = N'เบิก-จ่ายอะไหล่ตามใบงาน',
        IconName = N'output_outlined',
        SortOrder = 30
    WHERE MenuCode = N'18002';

    DELETE FROM dbo.TDADMenuGroup
    WHERE MenuGroupCode = N'18'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.TDADMainMenu
          WHERE MenuGroupCode = N'18'
      );

    COMMIT TRANSACTION;

    SELECT MenuCode, MenuGroupCode, MenuName, RouteName, SortOrder, IsActive
    FROM dbo.TDADMainMenu
    WHERE MenuCode IN (N'08002', N'08003')
    ORDER BY SortOrder;

    SELECT COUNT(*) AS RemainingInventoryGroup
    FROM dbo.TDADMenuGroup
    WHERE MenuGroupCode = N'18';

    SELECT MenuCode, COUNT(*) AS GrantedActionCount
    FROM dbo.TDADRoleGroupPermission
    WHERE MenuCode IN (N'08002', N'08003')
      AND IsAllowed = 1
    GROUP BY MenuCode
    ORDER BY MenuCode;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
