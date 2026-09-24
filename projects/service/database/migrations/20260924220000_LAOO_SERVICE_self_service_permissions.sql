DECLARE @ProjectID bigint =
(
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_SERVICE'
      AND IsActive = 1
);

IF @ProjectID IS NOT NULL
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADPermission
        WHERE ProjectID = @ProjectID
          AND ScreenCode = N'20001'
          AND ActionCode = N'VIEW'
    )
    BEGIN
        INSERT dbo.TDADPermission
        (
            ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
            ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate
        )
        VALUES
        (
            @ProjectID, N'20001', N'แจ้งซ่อม / ขอใช้บริการ', N'SELF_SERVICE_REQUEST',
            N'VIEW', N'ดูข้อมูล', N'View', 1, SYSUTCDATETIME()
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADPermission
        WHERE ProjectID = @ProjectID
          AND ScreenCode = N'20001'
          AND ActionCode = N'CREATE'
    )
    BEGIN
        INSERT dbo.TDADPermission
        (
            ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
            ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate
        )
        VALUES
        (
            @ProjectID, N'20001', N'แจ้งซ่อม / ขอใช้บริการ', N'SELF_SERVICE_REQUEST',
            N'CREATE', N'เพิ่ม', N'Create', 1, SYSUTCDATETIME()
        );
    END;
END;
