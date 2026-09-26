SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @P bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EVALUATION');
IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@P AND ScreenCode=N'47001' AND ActionCode=N'CREATE') INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) VALUES(@P,N'47001',N'ตั้งค่าระบบประเมิน',N'EVALUATION_SETTINGS',N'CREATE',N'CREATE',N'CREATE',1,SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@P AND ScreenCode=N'47001' AND ActionCode=N'DELETE') INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) VALUES(@P,N'47001',N'ตั้งค่าระบบประเมิน',N'EVALUATION_SETTINGS',N'DELETE',N'DELETE',N'DELETE',1,SYSUTCDATETIME());
COMMIT TRANSACTION;
