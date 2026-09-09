SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @MeetingProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_MEETING' AND IsActive=1
    ORDER BY ProjectID
);

IF @MeetingProjectID IS NULL
    THROW 51000, 'Active LAOO_MEETING project was not found.', 1;

DECLARE @Menus TABLE
(
    MenuCode char(5) PRIMARY KEY,
    MenuGroupCode char(2),
    MenuName nvarchar(200),
    ScreenType int,
    RouteName nvarchar(200),
    RoutePath nvarchar(500),
    FeatureCode nvarchar(100),
    IconName nvarchar(100),
    SortOrder int
);

INSERT @Menus VALUES
('21006','21',N'สรุปการสั่งอาหาร',3,N'meetingFoodOrderSummary',
 N'/company/meeting-food-order-summary',N'MEETING_FOOD_ORDER_SUMMARY',N'summarize',40),
('22004','22',N'รายการเช็คชื่อ',2,N'meetingAttendance',
 N'/company/meeting-attendance',N'MEETING_ATTENDANCE',N'how_to_reg',1);

INSERT dbo.TDADMainMenu
(
    MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,
    IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate
)
SELECT M.MenuCode,M.MenuGroupCode,M.MenuName,M.ScreenType,M.RouteName,M.RoutePath,
       M.FeatureCode,M.IconName,M.SortOrder,1,1,1,SYSDATETIME()
FROM @Menus M
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADMainMenu X WHERE X.MenuCode=M.MenuCode
);

UPDATE T
SET T.MenuGroupCode=M.MenuGroupCode,
    T.MenuName=M.MenuName,
    T.ScreenType=M.ScreenType,
    T.RouteName=M.RouteName,
    T.RoutePath=M.RoutePath,
    T.FeatureCode=M.FeatureCode,
    T.IconName=M.IconName,
    T.SortOrder=M.SortOrder,
    T.IsVisible=1,
    T.IsFavoriteAllowed=1,
    T.IsActive=1,
    T.UpdateDate=SYSDATETIME()
FROM dbo.TDADMainMenu T
JOIN @Menus M ON M.MenuCode=T.MenuCode;

UPDATE dbo.TDADMainMenu
SET IsVisible=0,UpdateDate=SYSDATETIME()
WHERE MenuCode='21005';

INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT @MeetingProjectID,M.MenuCode,M.MenuGroupCode,M.SortOrder,1
FROM @Menus M
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADProjectMenu X
    WHERE X.ProjectID=@MeetingProjectID AND X.MenuCode=M.MenuCode
);

UPDATE P
SET P.MenuGroupCode=M.MenuGroupCode,P.SortOrder=M.SortOrder,P.IsActive=1
FROM dbo.TDADProjectMenu P
JOIN @Menus M ON M.MenuCode=P.MenuCode
WHERE P.ProjectID=@MeetingProjectID;

DECLARE @Permissions TABLE
(
    ScreenCode nvarchar(50),
    ScreenNameTH nvarchar(200),
    ScreenNameEN nvarchar(200),
    ActionCode nvarchar(50),
    ActionNameTH nvarchar(200),
    ActionNameEN nvarchar(200),
    PRIMARY KEY(ScreenCode,ActionCode)
);

INSERT @Permissions VALUES
(N'21006',N'สรุปการสั่งอาหาร',N'Meeting food order summary',N'VIEW',N'ดูข้อมูล',N'View'),
(N'22004',N'รายการเช็คชื่อ',N'Meeting attendance',N'VIEW',N'ดูข้อมูล',N'View'),
(N'22004',N'รายการเช็คชื่อ',N'Meeting attendance',N'EDIT',N'แก้ไขข้อมูล',N'Edit');

INSERT dbo.TDADPermission
(
    ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,
    ActionNameTH,ActionNameEN,IsActive,CreatedDate
)
SELECT @MeetingProjectID,P.ScreenCode,P.ScreenNameTH,P.ScreenNameEN,
       P.ActionCode,P.ActionNameTH,P.ActionNameEN,1,SYSDATETIME()
FROM @Permissions P
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADPermission X
    WHERE X.ProjectID=@MeetingProjectID
      AND X.ScreenCode=P.ScreenCode
      AND X.ActionCode=P.ActionCode
);

UPDATE X
SET X.ScreenNameTH=P.ScreenNameTH,
    X.ScreenNameEN=P.ScreenNameEN,
    X.ActionNameTH=P.ActionNameTH,
    X.ActionNameEN=P.ActionNameEN,
    X.IsActive=1
FROM dbo.TDADPermission X
JOIN @Permissions P
  ON P.ScreenCode=X.ScreenCode AND P.ActionCode=X.ActionCode
WHERE X.ProjectID=@MeetingProjectID;

COMMIT TRANSACTION;
GO
