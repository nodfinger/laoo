SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @project IS NULL THROW 54290,N'Active My System project not found.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'69002' AND ScreenType=4 AND IsActive=1)
  THROW 54291,N'SC Request menu is missing or has changed.',1;

IF NOT EXISTS(
  SELECT 1 FROM dbo.TDADPermission
  WHERE ProjectID=@project AND ScreenCode=N'69002' AND ActionCode=N'UPLOAD'
)
BEGIN
  INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
  VALUES(@project,N'69002',N'SC Request',N'SC Request',N'UPLOAD',N'แนบไฟล์',N'Upload',1);
END;
