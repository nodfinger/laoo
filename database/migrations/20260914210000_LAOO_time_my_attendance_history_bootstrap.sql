/* Core-owned navigation and permission bootstrap for LAOO_TIME my attendance history. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
BEGIN TRANSACTION;

DECLARE @TimeProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1);
IF @TimeProjectID IS NULL THROW 52860,N'Active LAOO_TIME project is required.',1;

DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuGroupCode char(2),MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'30002',N'30',N'ประวัติการลงเวลาของฉัน',3,N'myAttendanceHistory',N'/company/my-attendance-history',N'TIME_MY_ATTENDANCE_HISTORY',N'history_outlined',20);

IF EXISTS(SELECT 1 FROM @Menus S JOIN dbo.TDADMainMenu T ON T.MenuCode=S.MenuCode WHERE T.ScreenType<>S.ScreenType OR ISNULL(T.RouteName,N'')<>S.RouteName OR ISNULL(T.RoutePath,N'')<>S.RoutePath) THROW 52861,N'My attendance history MenuCode conflicts with ScreenType or route.',1;
IF EXISTS(SELECT 1 FROM @Menus S JOIN dbo.TDADMainMenu T ON (T.RouteName=S.RouteName OR T.RoutePath=S.RoutePath) AND T.MenuCode<>S.MenuCode) THROW 52862,N'My attendance history RouteName or RoutePath is already used.',1;

UPDATE dbo.TDADMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'30';
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'30')
  THROW 52863,N'Menu group 30 must be bootstrapped before my attendance history.',1;

UPDATE T SET T.MenuGroupCode=S.MenuGroupCode,T.MenuName=S.MenuName,T.ScreenType=S.ScreenType,T.RouteName=S.RouteName,T.RoutePath=S.RoutePath,T.FeatureCode=S.FeatureCode,T.IconName=S.IconName,T.SortOrder=S.SortOrder,T.IsVisible=1,T.IsFavoriteAllowed=1,T.IsActive=1,T.ShowPermissionPoint=0,T.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADMainMenu T JOIN @Menus S ON S.MenuCode=T.MenuCode;
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT S.MenuCode,S.MenuGroupCode,S.MenuName,S.ScreenType,S.RouteName,S.RoutePath,S.FeatureCode,S.IconName,S.SortOrder,1,1,1,SYSUTCDATETIME(),0
FROM @Menus S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu T WHERE T.MenuCode=S.MenuCode);

UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@TimeProjectID AND MenuGroupCode=N'30';
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@TimeProjectID AND MenuGroupCode=N'30')
  INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@TimeProjectID,N'30',6,1,SYSUTCDATETIME());

UPDATE T SET T.MenuGroupCode=S.MenuGroupCode,T.SortOrder=S.SortOrder,T.IsActive=1,T.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADProjectMenu T JOIN @Menus S ON S.MenuCode=T.MenuCode WHERE T.ProjectID=@TimeProjectID;
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @TimeProjectID,S.MenuCode,S.MenuGroupCode,S.SortOrder,1,SYSUTCDATETIME()
FROM @Menus S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu T WHERE T.ProjectID=@TimeProjectID AND T.MenuCode=S.MenuCode);
UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'30002' AND ProjectID<>@TimeProjectID AND IsActive=1;

DECLARE @Permissions TABLE(ScreenCode nvarchar(50),ScreenNameTH nvarchar(200),ScreenNameEN nvarchar(200),ActionCode nvarchar(50),ActionNameTH nvarchar(200),ActionNameEN nvarchar(200),PRIMARY KEY(ScreenCode,ActionCode));
INSERT @Permissions VALUES
(N'30002',N'ประวัติการลงเวลาของฉัน',N'My attendance history',N'VIEW',N'ดูข้อมูล',N'View');
UPDATE T SET T.ScreenNameTH=S.ScreenNameTH,T.ScreenNameEN=S.ScreenNameEN,T.ActionNameTH=S.ActionNameTH,T.ActionNameEN=S.ActionNameEN,T.IsActive=1
FROM dbo.TDADPermission T JOIN @Permissions S ON S.ScreenCode=T.ScreenCode AND S.ActionCode=T.ActionCode WHERE T.ProjectID=@TimeProjectID;
UPDATE T SET T.IsActive=0 FROM dbo.TDADPermission T LEFT JOIN @Permissions S ON S.ScreenCode=T.ScreenCode AND S.ActionCode=T.ActionCode WHERE T.ProjectID=@TimeProjectID AND T.ScreenCode=N'30002' AND S.ScreenCode IS NULL;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @TimeProjectID,S.ScreenCode,S.ScreenNameTH,S.ScreenNameEN,S.ActionCode,S.ActionNameTH,S.ActionNameEN,1,SYSUTCDATETIME()
FROM @Permissions S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission T WHERE T.ProjectID=@TimeProjectID AND T.ScreenCode=S.ScreenCode AND T.ActionCode=S.ActionCode);

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
