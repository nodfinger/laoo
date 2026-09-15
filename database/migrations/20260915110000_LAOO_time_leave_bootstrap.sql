/* Core-owned navigation and permission bootstrap for LAOO_TIME leave work. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
BEGIN TRANSACTION;

DECLARE @TimeProjectID bigint =
(
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1
);
IF @TimeProjectID IS NULL
    THROW 52870,N'Active LAOO_TIME project is required.',1;

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
    (N'28009',N'28',N'ประเภทการลา',1,N'timeLeaveTypes',N'/company/time-leave-types',N'TIME_LEAVE_TYPES',N'category_outlined',90),
    (N'28010',N'28',N'เกณฑ์สิทธิ์การลา',1,N'timeLeaveEntitlementPolicies',N'/company/time-leave-entitlement-policies',N'TIME_LEAVE_ENTITLEMENT_POLICIES',N'policy_outlined',100),
    (N'26003',N'26',N'คำขอลา',4,N'timeLeaveRequests',N'/company/time-leave-requests',N'TIME_LEAVE_REQUESTS',N'event_note_outlined',30),
    (N'26004',N'26',N'กล่องอนุมัติคำขอลา',3,N'timeLeaveApprovalInbox',N'/company/time-leave-approval-inbox',N'TIME_LEAVE_APPROVAL_INBOX',N'approval_outlined',40),
    (N'30003',N'30',N'คำขอลาของฉัน',4,N'myLeaveRequests',N'/company/my-leave-requests',N'TIME_MY_LEAVE_REQUESTS',N'event_available_outlined',30);

IF EXISTS
(
    SELECT 1
    FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
    WHERE target.ScreenType<>source.ScreenType
       OR ISNULL(target.RouteName,N'')<>source.RouteName
       OR ISNULL(target.RoutePath,N'')<>source.RoutePath
)
    THROW 52871,N'Time leave MenuCode conflicts with existing ScreenType or route.',1;

IF EXISTS
(
    SELECT 1
    FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target
      ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
     AND target.MenuCode<>source.MenuCode
)
    THROW 52872,N'Time leave RouteName or RoutePath is already used.',1;

UPDATE dbo.TDADMenuGroup
SET IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode IN(N'26',N'28',N'30');
IF (SELECT COUNT(*) FROM dbo.TDADMenuGroup WHERE MenuGroupCode IN(N'26',N'28',N'30'))<>3
    THROW 52873,N'Time leave menu groups 26, 28 and 30 are required.',1;

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
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode
);

DECLARE @ProjectGroups TABLE(MenuGroupCode char(2) PRIMARY KEY,SortOrder int NOT NULL);
INSERT @ProjectGroups VALUES(N'26',2),(N'28',4),(N'30',6);

UPDATE target
SET target.SortOrder=source.SortOrder,
    target.IsActive=1,
    target.UpdateDate=SYSUTCDATETIME()
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
SET target.MenuGroupCode=source.MenuGroupCode,
    target.SortOrder=source.SortOrder,
    target.IsActive=1,
    target.UpdateDate=SYSUTCDATETIME()
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
WHERE MenuCode IN(N'28009',N'28010',N'26003',N'26004',N'30003')
  AND ProjectID<>@TimeProjectID
  AND IsActive=1;

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
    (N'28009',N'ประเภทการลา',N'Leave types',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'28009',N'ประเภทการลา',N'Leave types',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
    (N'28009',N'ประเภทการลา',N'Leave types',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'28009',N'ประเภทการลา',N'Leave types',N'DELETE',N'ลบข้อมูล',N'Delete'),
    (N'28010',N'เกณฑ์สิทธิ์การลา',N'Leave entitlement policies',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'28010',N'เกณฑ์สิทธิ์การลา',N'Leave entitlement policies',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
    (N'28010',N'เกณฑ์สิทธิ์การลา',N'Leave entitlement policies',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'28010',N'เกณฑ์สิทธิ์การลา',N'Leave entitlement policies',N'DELETE',N'ลบข้อมูล',N'Delete'),
    (N'26003',N'คำขอลา',N'Leave requests',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'26003',N'คำขอลา',N'Leave requests',N'CREATE',N'สร้างคำขอ',N'Create'),
    (N'26003',N'คำขอลา',N'Leave requests',N'SUBMIT',N'ส่งคำขอ',N'Submit'),
    (N'26003',N'คำขอลา',N'Leave requests',N'CANCEL',N'ยกเลิกคำขอ',N'Cancel'),
    (N'26003',N'คำขอลา',N'Leave requests',N'ACT_ON_BEHALF',N'ทำแทน',N'Act on behalf'),
    (N'26003',N'คำขอลา',N'Leave requests',N'APPROVE',N'อนุมัติ',N'Approve'),
    (N'26003',N'คำขอลา',N'Leave requests',N'SELF_APPROVE',N'อนุมัติคำขอของตนเอง',N'Self approve'),
    (N'26004',N'กล่องอนุมัติคำขอลา',N'Leave approval inbox',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'26004',N'กล่องอนุมัติคำขอลา',N'Leave approval inbox',N'APPROVE',N'อนุมัติ',N'Approve'),
    (N'26004',N'กล่องอนุมัติคำขอลา',N'Leave approval inbox',N'SELF_APPROVE',N'อนุมัติคำขอของตนเอง',N'Self approve'),
    (N'30003',N'คำขอลาของฉัน',N'My leave requests',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'30003',N'คำขอลาของฉัน',N'My leave requests',N'CREATE',N'สร้างคำขอ',N'Create'),
    (N'30003',N'คำขอลาของฉัน',N'My leave requests',N'SUBMIT',N'ส่งคำขอ',N'Submit'),
    (N'30003',N'คำขอลาของฉัน',N'My leave requests',N'CANCEL',N'ยกเลิกคำขอ',N'Cancel');

UPDATE target
SET target.ScreenNameTH=source.ScreenNameTH,
    target.ScreenNameEN=source.ScreenNameEN,
    target.ActionNameTH=source.ActionNameTH,
    target.ActionNameEN=source.ActionNameEN,
    target.IsActive=1,
    target.ModifiedDate=SYSUTCDATETIME()
FROM dbo.TDADPermission target
INNER JOIN @Permissions source
  ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode
WHERE target.ProjectID=@TimeProjectID;

UPDATE target
SET target.IsActive=0,target.ModifiedDate=SYSUTCDATETIME()
FROM dbo.TDADPermission target
LEFT JOIN @Permissions source
  ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode
WHERE target.ProjectID=@TimeProjectID
  AND target.ScreenCode IN(N'28009',N'28010',N'26003',N'26004',N'30003')
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
