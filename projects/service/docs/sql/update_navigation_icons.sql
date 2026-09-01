/*
  Assign semantic navigation icons to every menu known by the application.
  Safe to run repeatedly: only IconName is updated; routes and permissions are
  intentionally untouched.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @GroupIcons TABLE
    (
        MenuGroupCode nvarchar(20) NOT NULL PRIMARY KEY,
        IconName nvarchar(200) NOT NULL
    );

    INSERT INTO @GroupIcons (MenuGroupCode, IconName)
    VALUES
        (N'01', N'admin_panel_settings_outlined'),
        (N'02', N'manage_accounts_outlined'),
        (N'03', N'extension_outlined'),
        (N'04', N'policy_outlined'),
        (N'05', N'settings_outlined'),
        (N'06', N'business_center_outlined'),
        (N'07', N'manage_accounts_outlined'),
        (N'08', N'inventory_2_outlined'),
        (N'09', N'point_of_sale_outlined'),
        (N'10', N'admin_panel_settings_outlined'),
        (N'11', N'account_tree_outlined'),
        (N'12', N'groups_outlined'),
        (N'14', N'location_city_outlined'),
        (N'15', N'support_agent_outlined'),
        (N'16', N'event_repeat_outlined'),
        (N'17', N'engineering_outlined'),
        (N'19', N'analytics_outlined'),
        (N'20', N'contact_support_outlined');

    DECLARE @MenuIcons TABLE
    (
        MenuCode nvarchar(20) NOT NULL PRIMARY KEY,
        IconName nvarchar(200) NOT NULL
    );

    INSERT INTO @MenuIcons (MenuCode, IconName)
    VALUES
        (N'01001', N'handshake_outlined'),
        (N'01004', N'developer_mode_outlined'),
        (N'01005', N'tune_outlined'),
        (N'01006', N'policy_outlined'),
        (N'02001', N'support_agent_outlined'),
        (N'02002', N'badge_outlined'),
        (N'02003', N'corporate_fare_outlined'),
        (N'03001', N'extension_outlined'),
        (N'03002', N'hub_outlined'),
        (N'03003', N'shield_outlined'),
        (N'04001', N'fact_check_outlined'),
        (N'04002', N'login_outlined'),
        (N'05001', N'business_outlined'),
        (N'05002', N'storage_outlined'),
        (N'05003', N'tune_outlined'),
        (N'06001', N'corporate_fare_outlined'),
        (N'06002', N'store_outlined'),
        (N'07001', N'manage_accounts_outlined'),
        (N'08001', N'inventory_2_outlined'),
        (N'08002', N'inventory_2_outlined'),
        (N'08003', N'output_outlined'),
        (N'09001', N'person_search_outlined'),
        (N'09003', N'request_quote_outlined'),
        (N'09004', N'shopping_cart_checkout_outlined'),
        (N'09005', N'receipt_long_outlined'),
        (N'09006', N'local_shipping_outlined'),
        (N'09007', N'receipt_long_outlined'),
        (N'10001', N'badge_outlined'),
        (N'10002', N'manage_accounts_outlined'),
        (N'10003', N'groups_outlined'),
        (N'10004', N'admin_panel_settings_outlined'),
        (N'10005', N'account_tree_outlined'),
        (N'10006', N'device_hub_outlined'),
        (N'11001', N'badge_outlined'),
        (N'11002', N'manage_accounts_outlined'),
        (N'11003', N'groups_outlined'),
        (N'11004', N'admin_panel_settings_outlined'),
        (N'11005', N'account_tree_outlined'),
        (N'12001', N'badge_outlined'),
        (N'12002', N'support_agent_outlined'),
        (N'14001', N'location_city_outlined'),
        (N'14002', N'qr_code_2_outlined'),
        (N'14003', N'contact_page_outlined'),
        (N'15001', N'home_repair_service_outlined'),
        (N'15002', N'qr_code_scanner_outlined'),
        (N'16001', N'event_repeat_outlined'),
        (N'16002', N'checklist_outlined'),
        (N'16003', N'calendar_month_outlined'),
        (N'17001', N'view_kanban_outlined'),
        (N'17002', N'assignment_outlined'),
        (N'17003', N'task_alt_outlined'),
        (N'19001', N'dashboard_outlined'),
        (N'19002', N'history_outlined'),
        (N'19003', N'sentiment_satisfied_alt_outlined'),
        (N'20001', N'add_circle_outline'),
        (N'20002', N'track_changes_outlined'),
        (N'20003', N'history_outlined'),
        (N'20004', N'event_available_outlined'),
        (N'20005', N'star_outline'),
        (N'20006', N'report_problem_outlined');

    UPDATE Target
    SET Target.IconName = Source.IconName
    FROM dbo.TDADMenuGroup Target
    INNER JOIN @GroupIcons Source
        ON Source.MenuGroupCode = Target.MenuGroupCode
    WHERE ISNULL(Target.IconName, N'') <> Source.IconName;

    DECLARE @UpdatedGroups int = @@ROWCOUNT;

    UPDATE Target
    SET Target.IconName = Source.IconName
    FROM dbo.TDADMainMenu Target
    INNER JOIN @MenuIcons Source
        ON Source.MenuCode = Target.MenuCode
    WHERE ISNULL(Target.IconName, N'') <> Source.IconName;

    DECLARE @UpdatedMenus int = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @UpdatedGroups AS UpdatedMenuGroups,
           @UpdatedMenus AS UpdatedMainMenus;

    SELECT G.MenuGroupCode, G.MenuGroupName, G.IconName
    FROM dbo.TDADMenuGroup G
    INNER JOIN @GroupIcons I ON I.MenuGroupCode = G.MenuGroupCode
    ORDER BY G.SortOrder, G.MenuGroupCode;

    SELECT M.MenuCode, M.MenuName, M.IconName
    FROM dbo.TDADMainMenu M
    INNER JOIN @MenuIcons I ON I.MenuCode = M.MenuCode
    ORDER BY M.MenuGroupCode, M.SortOrder, M.MenuCode;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
