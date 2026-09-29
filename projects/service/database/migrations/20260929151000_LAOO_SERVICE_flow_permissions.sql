DECLARE @ProjectID bigint =
(
    SELECT ProjectID FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_SERVICE' AND IsActive = 1
);

IF @ProjectID IS NOT NULL
BEGIN
    DECLARE @Actions TABLE
    (
        ScreenCode nvarchar(20),
        ActionCode nvarchar(50),
        ActionNameTH nvarchar(100),
        ActionNameEN nvarchar(100)
    );
    INSERT @Actions VALUES
        (N'16003', N'VIEW', N'ดูข้อมูล', N'View'),
        (N'16003', N'EDIT', N'จัดการรอบ PM', N'Edit'),
        (N'17001', N'VIEW', N'ดูข้อมูล', N'View'),
        (N'17001', N'EDIT', N'มอบหมายงาน', N'Edit'),
        (N'17002', N'VIEW', N'ดูข้อมูล', N'View'),
        (N'17002', N'EDIT', N'ดำเนินงานซ่อม', N'Edit'),
        (N'20002', N'VIEW', N'ดูข้อมูล', N'View'),
        (N'20003', N'VIEW', N'ดูข้อมูล', N'View'),
        (N'20004', N'VIEW', N'ดูข้อมูล', N'View');

    UPDATE P
    SET IsActive = 1,
        ActionNameTH = A.ActionNameTH,
        ActionNameEN = A.ActionNameEN,
        ModifiedDate = SYSUTCDATETIME()
    FROM dbo.TDADPermission P
    JOIN @Actions A ON A.ScreenCode = P.ScreenCode
        AND A.ActionCode = P.ActionCode
    WHERE P.ProjectID = @ProjectID;

    INSERT dbo.TDADPermission
    (
        ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
        ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate
    )
    SELECT @ProjectID, A.ScreenCode, M.MenuName, M.RouteName,
           A.ActionCode, A.ActionNameTH, A.ActionNameEN, 1, SYSUTCDATETIME()
    FROM @Actions A
    JOIN dbo.TDADMainMenu M ON M.MenuCode = A.ScreenCode
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission P
        WHERE P.ProjectID = @ProjectID
          AND P.ScreenCode = A.ScreenCode
          AND P.ActionCode = A.ActionCode
    );

    UPDATE P
    SET IsActive = 0,
        ModifiedDate = SYSUTCDATETIME()
    FROM dbo.TDADPermission P
    WHERE P.ProjectID = @ProjectID
      AND P.ScreenCode IN (N'16003', N'17001', N'17002', N'20002', N'20003', N'20004')
      AND NOT EXISTS
      (
          SELECT 1 FROM @Actions A
          WHERE A.ScreenCode = P.ScreenCode
            AND A.ActionCode = P.ActionCode
      )
      AND P.IsActive = 1;

    UPDATE RP
    SET IsAllowed = 0
    FROM dbo.TDADRoleGroupPermission RP
    WHERE RP.ProjectID = @ProjectID
      AND RP.MenuCode IN (N'16003', N'17001', N'17002', N'20002', N'20003', N'20004')
      AND NOT EXISTS
      (
          SELECT 1 FROM @Actions A
          WHERE A.ScreenCode = RP.MenuCode
            AND A.ActionCode = RP.ActionCode
      )
      AND RP.IsAllowed = 1;
END;
