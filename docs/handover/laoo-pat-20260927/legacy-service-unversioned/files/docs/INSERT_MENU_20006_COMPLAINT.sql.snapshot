/*
  MenuCode  : 20006
  MenuName  : แจ้งเรื่องร้องเรียน
  Group     : 20
  ScreenType: 1 (CRUD)

  Script นี้รันซ้ำได้ และเปิด VIEW/CREATE/EDIT/DELETE ให้ Role กลุ่ม Admin
*/
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

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADMenuGroup
        WHERE MenuGroupCode = N'20' AND IsActive = 1
    )
        THROW 50002, 'ไม่พบกลุ่มเมนูรหัส 20 ที่เปิดใช้งาน', 1;

    IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'20006')
    BEGIN
        UPDATE dbo.TDADMainMenu
        SET MenuGroupCode = N'20',
            MenuName = N'แจ้งเรื่องร้องเรียน',
            ScreenType = 1,
            RouteName = N'portalComplaint',
            RoutePath = N'/portal/complaint',
            FeatureCode = N'MN206',
            IconName = N'report_problem_outlined',
            SortOrder = 60,
            IsVisible = 1,
            IsFavoriteAllowed = 0,
            IsActive = 1,
            ShowPermissionPoint = 0
        WHERE MenuCode = N'20006';
    END;
    ELSE
    BEGIN
        INSERT INTO dbo.TDADMainMenu
        (
            MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName,
            RoutePath, FeatureCode, IconName, SortOrder, IsVisible,
            IsFavoriteAllowed, IsActive, ShowPermissionPoint
        )
        VALUES
        (
            N'20006', N'20', N'แจ้งเรื่องร้องเรียน', 1,
            N'portalComplaint', N'/portal/complaint', N'MN206',
            N'report_problem_outlined', 60, 1, 0, 1, 0
        );
    END;

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

    UPDATE P
    SET P.ScreenNameTH = N'แจ้งเรื่องร้องเรียน',
        P.ScreenNameEN = N'portalComplaint',
        P.ActionNameTH = A.ActionNameTH,
        P.ActionNameEN = A.ActionNameEN,
        P.IsActive = 1
    FROM dbo.TDADPermission P
    INNER JOIN @Actions A ON A.ActionCode = P.ActionCode
    WHERE P.ProjectID = @ProjectID
      AND P.ScreenCode = N'20006';

    INSERT INTO dbo.TDADPermission
    (
        ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
        ActionCode, ActionNameTH, ActionNameEN, IsActive
    )
    SELECT
        @ProjectID, N'20006', N'แจ้งเรื่องร้องเรียน',
        N'portalComplaint', A.ActionCode, A.ActionNameTH, A.ActionNameEN, 1
    FROM @Actions A
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADPermission P
        WHERE P.ProjectID = @ProjectID
          AND P.ScreenCode = N'20006'
          AND P.ActionCode = A.ActionCode
    );

    UPDATE RP
    SET RP.IsAllowed = 1
    FROM dbo.TDADRoleGroupPermission RP
    INNER JOIN dbo.TDADRoleGroup R ON R.RoleGroupID = RP.RoleGroupID
    INNER JOIN @Actions A ON A.ActionCode = RP.ActionCode
    WHERE RP.ProjectID = @ProjectID
      AND RP.MenuCode = N'20006'
      AND R.ProjectID = @ProjectID
      AND R.ScopeType = N'C'
      AND R.IsActive = 1
      AND
      (
          UPPER(LTRIM(RTRIM(R.RoleCode))) IN (N'ADMIN', N'CA')
          OR UPPER(LTRIM(RTRIM(R.RoleNameTH))) = N'ADMIN'
          OR R.RoleNameTH LIKE N'%แอดมิน%'
          OR R.RoleNameTH LIKE N'%ผู้ดูแล%'
      );

    INSERT INTO dbo.TDADRoleGroupPermission
    (
        RoleGroupID, ProjectID, MenuCode, ActionCode, IsAllowed, CreatedBy
    )
    SELECT
        R.RoleGroupID, @ProjectID, N'20006', A.ActionCode, 1,
        N'insert-menu-20006'
    FROM dbo.TDADRoleGroup R
    CROSS JOIN @Actions A
    WHERE R.ProjectID = @ProjectID
      AND R.ScopeType = N'C'
      AND R.IsActive = 1
      AND
      (
          UPPER(LTRIM(RTRIM(R.RoleCode))) IN (N'ADMIN', N'CA')
          OR UPPER(LTRIM(RTRIM(R.RoleNameTH))) = N'ADMIN'
          OR R.RoleNameTH LIKE N'%แอดมิน%'
          OR R.RoleNameTH LIKE N'%ผู้ดูแล%'
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.TDADRoleGroupPermission RP
          WHERE RP.RoleGroupID = R.RoleGroupID
            AND RP.ProjectID = @ProjectID
            AND RP.MenuCode = N'20006'
            AND RP.ActionCode = A.ActionCode
      );

    COMMIT TRANSACTION;

    SELECT
        MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName,
        RoutePath, SortOrder, IsVisible, IsActive
    FROM dbo.TDADMainMenu
    WHERE MenuCode = N'20006';

    SELECT
        R.RoleGroupID, R.CompanyID, R.RoleCode, R.RoleNameTH,
        RP.ActionCode, RP.IsAllowed
    FROM dbo.TDADRoleGroupPermission RP
    INNER JOIN dbo.TDADRoleGroup R ON R.RoleGroupID = RP.RoleGroupID
    WHERE RP.ProjectID = @ProjectID
      AND RP.MenuCode = N'20006'
    ORDER BY R.CompanyID, R.RoleGroupID, RP.ActionCode;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
