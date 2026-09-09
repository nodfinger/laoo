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

IF @CenterProjectID IS NULL
    THROW 52320, N'ไม่พบ Project LAOO สำหรับเมนูส่วนกลาง', 1;

IF @ServiceProjectID IS NULL
    THROW 52321, N'ไม่พบ Project LAOO_SERVICE สำหรับย้ายเมนู', 1;

DECLARE @Groups TABLE
(
    MenuGroupCode char(2) NOT NULL PRIMARY KEY,
    SortOrder int NOT NULL
);
INSERT @Groups(MenuGroupCode, SortOrder)
VALUES (N'08', 1), (N'09', 2);

IF EXISTS
(
    SELECT 1
    FROM @Groups X
    LEFT JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=X.MenuGroupCode AND G.IsActive=1
    WHERE G.MenuGroupCode IS NULL
)
    THROW 52322, N'ไม่พบกลุ่มเมนูสินค้า-วัสดุหรือระบบขายที่เปิดใช้งาน', 1;

UPDATE PG
SET PG.SortOrder=X.SortOrder,
    PG.IsActive=1
FROM dbo.TDADProjectMenuGroup PG
INNER JOIN @Groups X ON X.MenuGroupCode=PG.MenuGroupCode
WHERE PG.ProjectID=@CenterProjectID;

INSERT dbo.TDADProjectMenuGroup(ProjectID, MenuGroupCode, SortOrder, IsActive)
SELECT @CenterProjectID, X.MenuGroupCode, X.SortOrder, 1
FROM @Groups X
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADProjectMenuGroup PG
    WHERE PG.ProjectID=@CenterProjectID AND PG.MenuGroupCode=X.MenuGroupCode
);

UPDATE PM
SET PM.MenuGroupCode=M.MenuGroupCode,
    PM.SortOrder=M.SortOrder,
    PM.IsActive=1
FROM dbo.TDADProjectMenu PM
INNER JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode
INNER JOIN @Groups X ON X.MenuGroupCode=M.MenuGroupCode
WHERE PM.ProjectID=@CenterProjectID;

INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive)
SELECT @CenterProjectID, M.MenuCode, M.MenuGroupCode, M.SortOrder, 1
FROM dbo.TDADMainMenu M
INNER JOIN @Groups X ON X.MenuGroupCode=M.MenuGroupCode
WHERE M.IsActive=1
  AND M.IsVisible=1
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.TDADProjectMenu PM
      WHERE PM.ProjectID=@CenterProjectID AND PM.MenuCode=M.MenuCode
  );

UPDATE PM
SET PM.IsActive=0
FROM dbo.TDADProjectMenu PM
INNER JOIN @Groups X ON X.MenuGroupCode=PM.MenuGroupCode
WHERE PM.ProjectID=@ServiceProjectID;

UPDATE PG
SET PG.IsActive=0
FROM dbo.TDADProjectMenuGroup PG
INNER JOIN @Groups X ON X.MenuGroupCode=PG.MenuGroupCode
WHERE PG.ProjectID=@ServiceProjectID;

COMMIT TRANSACTION;
