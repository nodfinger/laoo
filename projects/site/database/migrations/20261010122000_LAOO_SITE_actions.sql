SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @P bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SITE');
IF @P IS NULL THROW 63021,N'LAOO_SITE project missing',1;
DECLARE @A TABLE(MenuCode char(5),ActionCode nvarchar(30));
INSERT @A VALUES
(N'63003',N'SUBMIT'),(N'63003',N'UPLOAD'),(N'63003',N'DOWNLOAD'),
(N'63005',N'UPLOAD'),(N'63005',N'DOWNLOAD'),
(N'63006',N'UPLOAD'),(N'63006',N'DOWNLOAD'),
(N'63007',N'DOWNLOAD');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @P,M.MenuCode,M.MenuName,M.RouteName,A.ActionCode,A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM @A A JOIN dbo.TDADMainMenu M ON M.MenuCode=A.MenuCode
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@P AND P.ScreenCode=A.MenuCode AND P.ActionCode=A.ActionCode);
GO
