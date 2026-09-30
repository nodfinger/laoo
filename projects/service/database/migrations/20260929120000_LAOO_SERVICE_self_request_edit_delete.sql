DECLARE @ProjectID bigint =
(
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_SERVICE' AND IsActive = 1
);

IF @ProjectID IS NOT NULL
BEGIN
    DECLARE @Actions TABLE
    (
        ActionCode nvarchar(50),
        ActionNameTH nvarchar(100),
        ActionNameEN nvarchar(100)
    );
    INSERT @Actions VALUES
        (N'EDIT', N'แก้ไข', N'Edit'),
        (N'DELETE', N'ลบ', N'Delete');

    UPDATE P
    SET ScreenNameTH = N'แจ้งซ่อม / ขอใช้บริการ',
        ScreenNameEN = N'SELF_SERVICE_REQUEST',
        ActionNameTH = A.ActionNameTH,
        ActionNameEN = A.ActionNameEN,
        IsActive = 1,
        ModifiedDate = SYSUTCDATETIME()
    FROM dbo.TDADPermission P
    JOIN @Actions A ON A.ActionCode = P.ActionCode
    WHERE P.ProjectID = @ProjectID AND P.ScreenCode = N'20001';

    INSERT dbo.TDADPermission
    (
        ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN,
        ActionCode, ActionNameTH, ActionNameEN, IsActive, CreatedDate
    )
    SELECT
        @ProjectID, N'20001', N'แจ้งซ่อม / ขอใช้บริการ', N'SELF_SERVICE_REQUEST',
        A.ActionCode, A.ActionNameTH, A.ActionNameEN, 1, SYSUTCDATETIME()
    FROM @Actions A
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADPermission P
        WHERE P.ProjectID = @ProjectID
          AND P.ScreenCode = N'20001'
          AND P.ActionCode = A.ActionCode
    );
END;
