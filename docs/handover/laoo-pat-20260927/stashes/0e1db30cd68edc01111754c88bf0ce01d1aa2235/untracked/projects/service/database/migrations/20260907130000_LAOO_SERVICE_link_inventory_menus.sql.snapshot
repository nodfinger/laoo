SET XACT_ABORT ON;

DECLARE @ProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_SERVICE' AND IsActive = 1
);

IF @ProjectID IS NULL
    THROW 52307, N'ไม่พบ Project LAOO_SERVICE สำหรับผูกเมนูคลังสินค้า', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADProjectMenuGroup
    WHERE ProjectID = @ProjectID AND MenuGroupCode = N'08'
)
    INSERT dbo.TDADProjectMenuGroup(ProjectID, MenuGroupCode, SortOrder, IsActive)
    VALUES(@ProjectID, N'08', 80, 1);

INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive)
SELECT @ProjectID, M.MenuCode, M.MenuGroupCode, M.SortOrder, 1
FROM dbo.TDADMainMenu M
WHERE M.MenuCode IN (N'08004', N'08005', N'08006')
  AND M.MenuGroupCode = N'08'
  AND M.IsActive = 1
  AND M.IsVisible = 1
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.TDADProjectMenu P
      WHERE P.ProjectID = @ProjectID
        AND P.MenuCode = M.MenuCode
        AND P.MenuGroupCode = M.MenuGroupCode
  );
