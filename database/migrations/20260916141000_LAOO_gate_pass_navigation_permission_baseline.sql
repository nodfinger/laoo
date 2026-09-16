/* Core-owned Gate Pass navigation and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
BEGIN TRANSACTION;

DECLARE @ProjectID bigint =
(
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_GATE_PASS' AND IsActive=1
);
IF @ProjectID IS NULL
    THROW 52900,N'Active LAOO_GATE_PASS project is required.',1;

DECLARE @MenuGroupCode char(2)=N'38';

UPDATE dbo.TDADMenuGroup
SET AudienceType=N'C',
    MenuGroupName=N'ระบบนำทรัพย์สินออกนอกพื้นที่',
    IconName=N'outbound_outlined',
    SortOrder=380,
    IsExpandedDefault=0,
    IsActive=1,
    ShowPermissionPoint=0,
    OpenOption=0,
    UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode=@MenuGroupCode;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode)
    INSERT dbo.TDADMenuGroup
    (
        AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,
        IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption
    )
    VALUES
    (
        N'C',@MenuGroupCode,N'ระบบนำทรัพย์สินออกนอกพื้นที่',N'outbound_outlined',380,
        0,1,SYSUTCDATETIME(),0,0
    );

DECLARE @Menus TABLE
(
    MenuCode char(5) PRIMARY KEY,
    MenuName nvarchar(150) NOT NULL,
    ScreenType int NOT NULL,
    RouteName nvarchar(150) NOT NULL,
    RoutePath nvarchar(300) NOT NULL,
    FeatureCode nvarchar(100) NOT NULL,
    IconName nvarchar(100) NOT NULL,
    SortOrder int NOT NULL
);
INSERT @Menus VALUES
    (N'38001',N'ตั้งค่าระบบนำทรัพย์สินออก',2,N'gatePassSettings',N'/company/gate-pass-settings',N'GATE_PASS_SETTINGS',N'settings_outlined',10),
    (N'38002',N'วัตถุประสงค์การนำออก',1,N'gatePassPurposes',N'/company/gate-pass-purposes',N'GATE_PASS_PURPOSES',N'category_outlined',20),
    (N'38003',N'ใบขอนำทรัพย์สินออก',4,N'gatePassRequests',N'/company/gate-passes',N'GATE_PASS_REQUESTS',N'outbound_outlined',30),
    (N'38004',N'กล่องอนุมัติใบขอนำทรัพย์สินออก',3,N'gatePassApprovalInbox',N'/company/gate-pass-approvals',N'GATE_PASS_APPROVAL',N'approval_outlined',40),
    (N'38005',N'ตรวจปล่อยทรัพย์สินออก',2,N'gatePassExitCheck',N'/company/gate-pass-exit-check',N'GATE_PASS_EXIT_CHECK',N'qr_code_scanner_outlined',50),
    (N'38006',N'ติดตามรับทรัพย์สินกลับ',2,N'gatePassReturnTracking',N'/company/gate-pass-returns',N'GATE_PASS_RETURN',N'assignment_return_outlined',60),
    (N'38007',N'ใบขอนำทรัพย์สินออกของฉัน',4,N'myGatePasses',N'/company/my-gate-passes',N'MY_GATE_PASSES',N'person_outline',70),
    (N'38008',N'รายงานการนำทรัพย์สินออก',3,N'gatePassReports',N'/company/gate-pass-reports',N'GATE_PASS_REPORTS',N'assessment_outlined',80);

IF EXISTS
(
    SELECT 1
    FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
    WHERE target.ScreenType<>source.ScreenType
       OR ISNULL(target.RouteName,N'')<>source.RouteName
       OR ISNULL(target.RoutePath,N'')<>source.RoutePath
)
    THROW 52901,N'LAOO_GATE_PASS MenuCode conflicts with existing ScreenType or route.',1;

IF EXISTS
(
    SELECT 1
    FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target
      ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
     AND target.MenuCode<>source.MenuCode
)
    THROW 52902,N'LAOO_GATE_PASS RouteName or RoutePath is already used.',1;

UPDATE target
SET target.MenuGroupCode=@MenuGroupCode,
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
SELECT source.MenuCode,@MenuGroupCode,source.MenuName,source.ScreenType,
       source.RouteName,source.RoutePath,source.FeatureCode,source.IconName,
       source.SortOrder,1,1,1,SYSUTCDATETIME(),0
FROM @Menus source
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode);

UPDATE dbo.TDADProjectMenuGroup
SET SortOrder=1,IsActive=0,UpdateDate=SYSUTCDATETIME()
WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.TDADProjectMenuGroup
    WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode
)
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(@ProjectID,@MenuGroupCode,1,0,SYSUTCDATETIME());

UPDATE target
SET target.MenuGroupCode=@MenuGroupCode,
    target.SortOrder=source.SortOrder,
    target.IsActive=0,
    target.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADProjectMenu target
INNER JOIN @Menus source ON source.MenuCode=target.MenuCode
WHERE target.ProjectID=@ProjectID;

INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ProjectID,source.MenuCode,@MenuGroupCode,source.SortOrder,0,SYSUTCDATETIME()
FROM @Menus source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADProjectMenu target
    WHERE target.ProjectID=@ProjectID AND target.MenuCode=source.MenuCode
);

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
    (N'38001',N'ตั้งค่าระบบนำทรัพย์สินออก',N'Gate Pass settings',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'38001',N'ตั้งค่าระบบนำทรัพย์สินออก',N'Gate Pass settings',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'38002',N'วัตถุประสงค์การนำออก',N'Gate Pass purposes',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'38002',N'วัตถุประสงค์การนำออก',N'Gate Pass purposes',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
    (N'38002',N'วัตถุประสงค์การนำออก',N'Gate Pass purposes',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'38002',N'วัตถุประสงค์การนำออก',N'Gate Pass purposes',N'DELETE',N'ลบข้อมูล',N'Delete'),
    (N'38003',N'ใบขอนำทรัพย์สินออก',N'Gate Pass requests',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'38003',N'ใบขอนำทรัพย์สินออก',N'Gate Pass requests',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
    (N'38003',N'ใบขอนำทรัพย์สินออก',N'Gate Pass requests',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'38003',N'ใบขอนำทรัพย์สินออก',N'Gate Pass requests',N'DELETE',N'ลบข้อมูล',N'Delete'),
    (N'38003',N'ใบขอนำทรัพย์สินออก',N'Gate Pass requests',N'SUBMIT',N'ส่งอนุมัติ',N'Submit'),
    (N'38003',N'ใบขอนำทรัพย์สินออก',N'Gate Pass requests',N'CANCEL',N'ยกเลิก',N'Cancel'),
    (N'38003',N'ใบขอนำทรัพย์สินออก',N'Gate Pass requests',N'ACT_ON_BEHALF',N'ทำรายการแทน',N'Act on behalf'),
    (N'38004',N'กล่องอนุมัติใบขอนำทรัพย์สินออก',N'Gate Pass approval inbox',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'38004',N'กล่องอนุมัติใบขอนำทรัพย์สินออก',N'Gate Pass approval inbox',N'APPROVE',N'อนุมัติ',N'Approve'),
    (N'38004',N'กล่องอนุมัติใบขอนำทรัพย์สินออก',N'Gate Pass approval inbox',N'SELF_APPROVE',N'อนุมัติรายการของตนเอง',N'Self approve'),
    (N'38005',N'ตรวจปล่อยทรัพย์สินออก',N'Gate Pass exit check',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'38005',N'ตรวจปล่อยทรัพย์สินออก',N'Gate Pass exit check',N'CONFIRM_EXIT',N'ยืนยันการนำออก',N'Confirm exit'),
    (N'38006',N'ติดตามรับทรัพย์สินกลับ',N'Gate Pass return tracking',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'38006',N'ติดตามรับทรัพย์สินกลับ',N'Gate Pass return tracking',N'CONFIRM_RETURN',N'ยืนยันรับคืน',N'Confirm return'),
    (N'38007',N'ใบขอนำทรัพย์สินออกของฉัน',N'My Gate Passes',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'38007',N'ใบขอนำทรัพย์สินออกของฉัน',N'My Gate Passes',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
    (N'38007',N'ใบขอนำทรัพย์สินออกของฉัน',N'My Gate Passes',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'38007',N'ใบขอนำทรัพย์สินออกของฉัน',N'My Gate Passes',N'DELETE',N'ลบข้อมูล',N'Delete'),
    (N'38007',N'ใบขอนำทรัพย์สินออกของฉัน',N'My Gate Passes',N'SUBMIT',N'ส่งอนุมัติ',N'Submit'),
    (N'38007',N'ใบขอนำทรัพย์สินออกของฉัน',N'My Gate Passes',N'CANCEL',N'ยกเลิก',N'Cancel'),
    (N'38008',N'รายงานการนำทรัพย์สินออก',N'Gate Pass reports',N'VIEW',N'ดูข้อมูล',N'View');

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
WHERE target.ProjectID=@ProjectID;

INSERT dbo.TDADPermission
(
    ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,
    ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate
)
SELECT @ProjectID,source.ScreenCode,source.ScreenNameTH,source.ScreenNameEN,
       source.ActionCode,source.ActionNameTH,source.ActionNameEN,1,SYSUTCDATETIME()
FROM @Permissions source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADPermission target
    WHERE target.ProjectID=@ProjectID
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
