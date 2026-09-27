SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @CenterProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO' AND IsActive = 1
);
DECLARE @ServiceProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_SERVICE' AND IsActive = 1
);
DECLARE @MenuGroupCode char(2) = N'14';

IF @CenterProjectID IS NULL
    THROW 52330, N'ไม่พบ Project LAOO สำหรับเมนูส่วนกลาง', 1;

IF @ServiceProjectID IS NULL
    THROW 52331, N'ไม่พบ Project LAOO_SERVICE สำหรับย้ายเมนู', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADMenuGroup
    WHERE MenuGroupCode = @MenuGroupCode AND IsActive = 1
)
    THROW 52332, N'ไม่พบกลุ่มเมนูสถานที่และทรัพย์สินที่เปิดใช้งาน', 1;

UPDATE dbo.TDADProjectMenuGroup
SET SortOrder = 3,
    IsActive = 1
WHERE ProjectID = @CenterProjectID
  AND MenuGroupCode = @MenuGroupCode;

INSERT dbo.TDADProjectMenuGroup(ProjectID, MenuGroupCode, SortOrder, IsActive)
SELECT @CenterProjectID, @MenuGroupCode, 3, 1
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADProjectMenuGroup
    WHERE ProjectID = @CenterProjectID AND MenuGroupCode = @MenuGroupCode
);

UPDATE PM
SET PM.MenuGroupCode = M.MenuGroupCode,
    PM.SortOrder = M.SortOrder,
    PM.IsActive = 1
FROM dbo.TDADProjectMenu PM
INNER JOIN dbo.TDADMainMenu M ON M.MenuCode = PM.MenuCode
WHERE PM.ProjectID = @CenterProjectID
  AND M.MenuGroupCode = @MenuGroupCode;

INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive)
SELECT @CenterProjectID, M.MenuCode, M.MenuGroupCode, M.SortOrder, 1
FROM dbo.TDADMainMenu M
WHERE M.MenuGroupCode = @MenuGroupCode
  AND M.IsActive = 1
  AND M.IsVisible = 1
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.TDADProjectMenu PM
      WHERE PM.ProjectID = @CenterProjectID AND PM.MenuCode = M.MenuCode
  );

UPDATE PM
SET PM.IsActive = 0
FROM dbo.TDADProjectMenu PM
WHERE PM.ProjectID = @ServiceProjectID
  AND PM.MenuGroupCode = @MenuGroupCode;

UPDATE dbo.TDADProjectMenuGroup
SET IsActive = 0
WHERE ProjectID = @ServiceProjectID
  AND MenuGroupCode = @MenuGroupCode;

COMMIT TRANSACTION;
