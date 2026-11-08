SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE CONVERT(nvarchar(20), MenuCode)=N'10001' AND MenuGroupCode=N'10' AND ScreenType=1 AND IsActive=1)
    THROW 53041, N'Employee menu metadata does not match expected scope.', 1;

UPDATE dbo.TDADMenuGroup SET ShowPermissionPoint=1, UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode=N'10' AND ISNULL(ShowPermissionPoint,0)<>1;

UPDATE dbo.TDADMainMenu SET ShowPermissionPoint=1, UpdateDate=SYSUTCDATETIME()
WHERE CONVERT(nvarchar(20),MenuCode)=N'10001' AND ISNULL(ShowPermissionPoint,0)<>1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADUserPermissionPointName WHERE MenuCode=N'10001' AND PermissionPointCode=N'SHOW_EMPLOYEE_IMAGE')
    INSERT dbo.TDADUserPermissionPointName(MenuCode,PermissionPointCode,PermissionPointName,PermissionPointDescription,SortOrder,IsActive)
    SELECT N'10001',N'SHOW_EMPLOYEE_IMAGE',N'แสดงรูปพนักงาน',N'อนุญาตให้แสดงตัวเลือกรูปพนักงานในรายการ',ISNULL(MAX(SortOrder),0)+1,1
    FROM dbo.TDADUserPermissionPointName WHERE MenuCode=N'10001';
