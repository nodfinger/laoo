SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @ProjectID bigint = (
  SELECT ProjectID
  FROM dbo.TDADProject
  WHERE ProjectCode = N'LAOO_MEETING' AND IsActive = 1
);
IF @ProjectID IS NULL THROW 51000, 'Active LAOO_MEETING project was not found.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = '22006')
  INSERT dbo.TDADMainMenu
    (MenuCode, MenuGroupCode, MenuName, ScreenType, RouteName, RoutePath,
     FeatureCode, IconName, SortOrder, IsVisible, IsFavoriteAllowed, IsActive,
     CreateDate)
  VALUES
    ('22006', '23', N'กำหนดค่าระบบ Meeting', 2, N'meetingSystemSettings',
     N'/company/meeting-system-settings', N'MEETING_SYSTEM_SETTINGS',
     N'settings', 40, 1, 1, 1, SYSDATETIME());
ELSE
  UPDATE dbo.TDADMainMenu
  SET MenuGroupCode = '23', MenuName = N'กำหนดค่าระบบ Meeting', ScreenType = 2,
      RouteName = N'meetingSystemSettings',
      RoutePath = N'/company/meeting-system-settings',
      FeatureCode = N'MEETING_SYSTEM_SETTINGS', IconName = N'settings',
      SortOrder = 40, IsVisible = 1, IsFavoriteAllowed = 1, IsActive = 1,
      UpdateDate = SYSDATETIME()
  WHERE MenuCode = '22006';

IF NOT EXISTS (
  SELECT 1 FROM dbo.TDADProjectMenu
  WHERE ProjectID = @ProjectID AND MenuCode = '22006'
)
  INSERT dbo.TDADProjectMenu(ProjectID, MenuCode, MenuGroupCode, SortOrder, IsActive)
  VALUES(@ProjectID, '22006', '23', 40, 1);
ELSE
  UPDATE dbo.TDADProjectMenu
  SET MenuGroupCode = '23', SortOrder = 40, IsActive = 1
  WHERE ProjectID = @ProjectID AND MenuCode = '22006';

DECLARE @Permissions TABLE(
  ActionCode varchar(20), ActionNameTH nvarchar(100), ActionNameEN nvarchar(100)
);
INSERT @Permissions VALUES
  ('VIEW', N'ดูข้อมูล', N'View'),
  ('EDIT', N'แก้ไขข้อมูล', N'Edit');

INSERT dbo.TDADPermission
  (ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN, ActionCode,
   ActionNameTH, ActionNameEN, IsActive, CreatedDate)
SELECT @ProjectID, '22006', N'กำหนดค่าระบบ Meeting', N'Meeting system settings',
       P.ActionCode, P.ActionNameTH, P.ActionNameEN, 1, SYSDATETIME()
FROM @Permissions P
WHERE NOT EXISTS (
  SELECT 1 FROM dbo.TDADPermission X
  WHERE X.ProjectID = @ProjectID AND X.ScreenCode = '22006'
    AND X.ActionCode = P.ActionCode
);

COMMIT TRANSACTION;
GO
