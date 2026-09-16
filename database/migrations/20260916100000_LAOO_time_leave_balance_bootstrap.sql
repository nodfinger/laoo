/* Core-owned navigation and permission bootstrap for LAOO_TIME leave balances. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
BEGIN TRANSACTION;

DECLARE @TimeProjectID bigint =
(
    SELECT ProjectID FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1
);
IF @TimeProjectID IS NULL
    THROW 52880,N'Active LAOO_TIME project is required.',1;

DECLARE @Menus TABLE
(
    MenuCode char(5) PRIMARY KEY,
    MenuGroupCode char(2) NOT NULL,
    MenuName nvarchar(150) NOT NULL,
    ScreenType int NOT NULL,
    RouteName nvarchar(150) NOT NULL,
    RoutePath nvarchar(300) NOT NULL,
    FeatureCode nvarchar(100) NOT NULL,
    IconName nvarchar(100) NOT NULL,
    SortOrder int NOT NULL
);
INSERT @Menus VALUES
    (N'28011',N'28',N'สิทธิ์ลาคงเหลือ',3,N'timeLeaveBalances',N'/company/time-leave-balances',N'TIME_LEAVE_BALANCES',N'account_balance_wallet_outlined',110),
    (N'30004',N'30',N'สิทธิ์ลาคงเหลือของฉัน',3,N'myLeaveBalance',N'/company/my-leave-balance',N'TIME_MY_LEAVE_BALANCE',N'account_balance_wallet_outlined',40);

IF EXISTS
(
    SELECT 1 FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
    WHERE target.ScreenType<>source.ScreenType
       OR ISNULL(target.RouteName,N'')<>source.RouteName
       OR ISNULL(target.RoutePath,N'')<>source.RoutePath
)
    THROW 52881,N'Time leave balance MenuCode conflicts with existing ScreenType or route.',1;

IF EXISTS
(
    SELECT 1 FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target
      ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
     AND target.MenuCode<>source.MenuCode
)
    THROW 52882,N'Time leave balance RouteName or RoutePath is already used.',1;

UPDATE dbo.TDADMenuGroup
SET IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode IN(N'28',N'30');
IF (SELECT COUNT(*) FROM dbo.TDADMenuGroup WHERE MenuGroupCode IN(N'28',N'30'))<>2
    THROW 52883,N'Time leave balance menu groups 28 and 30 are required.',1;

UPDATE target
SET target.MenuGroupCode=source.MenuGroupCode,
    target.MenuName=source.MenuName,
    target.ScreenType=source.ScreenType,
    target.RouteName=source.RouteName,
    target.RoutePath=source.RoutePath,
    target.FeatureCode=source.FeatureCode,
    target.IconName=source.IconName,
    target.SortOrder=source.SortOrder,
    target.IsVisible=1,
    target.IsFavoriteAllowed=1,
    target.IsActive=1,
    target.ShowPermissionPoint=0,
    target.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADMainMenu target
INNER JOIN @Menus source ON source.MenuCode=target.MenuCode;

INSERT dbo.TDADMainMenu
(
    MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,
    IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint
)
SELECT source.MenuCode,source.MenuGroupCode,source.MenuName,source.ScreenType,
       source.RouteName,source.RoutePath,source.FeatureCode,source.IconName,
       source.SortOrder,1,1,1,SYSUTCDATETIME(),0
FROM @Menus source
WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode);

DECLARE @ProjectGroups TABLE(MenuGroupCode char(2) PRIMARY KEY,SortOrder int NOT NULL);
INSERT @ProjectGroups VALUES(N'28',4),(N'30',6);

UPDATE target
SET target.SortOrder=source.SortOrder,target.IsActive=1,target.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADProjectMenuGroup target
INNER JOIN @ProjectGroups source ON source.MenuGroupCode=target.MenuGroupCode
WHERE target.ProjectID=@TimeProjectID;

INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @TimeProjectID,source.MenuGroupCode,source.SortOrder,1,SYSUTCDATETIME()
FROM @ProjectGroups source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADProjectMenuGroup target
    WHERE target.ProjectID=@TimeProjectID AND target.MenuGroupCode=source.MenuGroupCode
);

UPDATE target
SET target.MenuGroupCode=source.MenuGroupCode,target.SortOrder=source.SortOrder,
    target.IsActive=1,target.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADProjectMenu target
INNER JOIN @Menus source ON source.MenuCode=target.MenuCode
WHERE target.ProjectID=@TimeProjectID;

INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @TimeProjectID,source.MenuCode,source.MenuGroupCode,source.SortOrder,1,SYSUTCDATETIME()
FROM @Menus source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADProjectMenu target
    WHERE target.ProjectID=@TimeProjectID AND target.MenuCode=source.MenuCode
);

UPDATE dbo.TDADProjectMenu
SET IsActive=0,UpdateDate=SYSUTCDATETIME()
WHERE MenuCode IN(N'28011',N'30004') AND ProjectID<>@TimeProjectID AND IsActive=1;

DECLARE @Permissions TABLE
(
    ScreenCode nvarchar(50) NOT NULL,
    ScreenNameTH nvarchar(200) NOT NULL,
    ScreenNameEN nvarchar(200) NOT NULL,
    ActionCode nvarchar(50) NOT NULL,
    ActionNameTH nvarchar(200) NOT NULL,
    ActionNameEN nvarchar(200) NOT NULL,
    PRIMARY KEY(ScreenCode,ActionCode)
);
INSERT @Permissions VALUES
    (N'28011',N'สิทธิ์ลาคงเหลือ',N'Leave balances',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'30004',N'สิทธิ์ลาคงเหลือของฉัน',N'My leave balance',N'VIEW',N'ดูข้อมูล',N'View');

UPDATE target
SET target.ScreenNameTH=source.ScreenNameTH,target.ScreenNameEN=source.ScreenNameEN,
    target.ActionNameTH=source.ActionNameTH,target.ActionNameEN=source.ActionNameEN,
    target.IsActive=1,target.ModifiedDate=SYSUTCDATETIME()
FROM dbo.TDADPermission target
INNER JOIN @Permissions source ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode
WHERE target.ProjectID=@TimeProjectID;

UPDATE target
SET target.IsActive=0,target.ModifiedDate=SYSUTCDATETIME()
FROM dbo.TDADPermission target
LEFT JOIN @Permissions source ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode
WHERE target.ProjectID=@TimeProjectID
  AND target.ScreenCode IN(N'28011',N'30004')
  AND source.ScreenCode IS NULL;

INSERT dbo.TDADPermission
(
    ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,
    ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate
)
SELECT @TimeProjectID,source.ScreenCode,source.ScreenNameTH,source.ScreenNameEN,
       source.ActionCode,source.ActionNameTH,source.ActionNameEN,1,SYSUTCDATETIME()
FROM @Permissions source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADPermission target
    WHERE target.ProjectID=@TimeProjectID
      AND target.ScreenCode=source.ScreenCode
      AND target.ActionCode=source.ActionCode
);

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
