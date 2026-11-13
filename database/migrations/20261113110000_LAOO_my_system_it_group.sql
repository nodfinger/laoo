SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @project IS NULL THROW 54260,N'Active My System project not found.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'65' AND IsActive=1)
  THROW 54261,N'My System IT menu group is missing.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'65001' AND MenuGroupCode=N'65')
  THROW 54262,N'My System settings menu is missing.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'65002' AND MenuGroupCode=N'65')
  THROW 54263,N'SAP-PMS menu is missing.',1;

UPDATE dbo.TDADMenuGroup
SET MenuGroupName=N'ระบบ-IT',IconName=N'computer',UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode=N'65';

UPDATE dbo.TDADMainMenu
SET MenuName=N'กำหนดค่าระบบ',UpdateDate=SYSUTCDATETIME()
WHERE MenuCode=N'65001';

UPDATE dbo.TDADPermission
SET ScreenNameTH=N'กำหนดค่าระบบ'
WHERE ProjectID=@project AND ScreenCode=N'65001';
