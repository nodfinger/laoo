/* Enable and seed the employee-level permission point for stock receipt confirmation. */
SET XACT_ABORT ON;

UPDATE dbo.TDADMainMenu
SET ShowPermissionPoint=1,
    UpdateDate=SYSUTCDATETIME()
WHERE CONVERT(nvarchar(20),MenuCode)=N'08005'
  AND IsActive=1;

IF EXISTS (
    SELECT 1
    FROM dbo.TDADMainMenu
    WHERE CONVERT(nvarchar(20),MenuCode)=N'08005'
      AND IsActive=1
)
AND NOT EXISTS (
    SELECT 1
    FROM dbo.TDADUserPermissionPointName
    WHERE MenuCode=N'08005'
      AND PermissionPointCode=N'CONFIRM_STOCK'
)
BEGIN
    INSERT dbo.TDADUserPermissionPointName
        (MenuCode,PermissionPointCode,PermissionPointName,PermissionPointDescription,SortOrder,IsActive)
    SELECT N'08005',N'CONFIRM_STOCK',N'ยืนยันเข้าสต๊อก',
           N'อนุญาตให้ยืนยันใบรับสินค้าและบันทึกยอดเข้าสต๊อก',
           ISNULL(MAX(SortOrder),0)+1,1
    FROM dbo.TDADUserPermissionPointName
    WHERE MenuCode=N'08005';
END;
GO
