SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10001' AND IsActive=1)
    THROW 53041, N'Employee menu is missing.', 1;
IF OBJECT_ID(N'dbo.TDADEmployeeSignature',N'U') IS NULL
    CREATE TABLE dbo.TDADEmployeeSignature (
        EmployeeID bigint NOT NULL PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ImageData varbinary(max) NOT NULL,
        ContentType nvarchar(100) NOT NULL,
        FileName nvarchar(250) NOT NULL,
        UpdatedBy bigint NOT NULL,
        UpdateDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
IF NOT EXISTS (SELECT 1 FROM dbo.TDADUserPermissionPointName WHERE MenuCode=N'10001' AND PermissionPointCode=N'MANAGE_EMPLOYEE_SIGNATURE')
    INSERT dbo.TDADUserPermissionPointName(MenuCode,PermissionPointCode,PermissionPointName,PermissionPointDescription,SortOrder,IsActive)
    SELECT N'10001',N'MANAGE_EMPLOYEE_SIGNATURE',N'กำหนดลายเซ็น',N'อนุญาตให้แนบรูปลายเซ็นของพนักงาน',ISNULL(MAX(SortOrder),0)+1,1
    FROM dbo.TDADUserPermissionPointName WHERE MenuCode=N'10001';
