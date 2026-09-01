USE [DBTDLaooService];
GO

/* Project/Menu baseline for the combined LAOO + LAOO_MEETING database.
   Business-table DDL/data migration is intentionally separate. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADProjectMenuGroup',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADProjectMenuGroup
    (
        ProjectID bigint NOT NULL,
        MenuGroupCode char(2) NOT NULL,
        SortOrder int NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADProjectMenuGroup_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADProjectMenuGroup_CreateDate DEFAULT(SYSDATETIME()),
        CreateBy bigint NULL, UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
        CONSTRAINT PK_TDADProjectMenuGroup PRIMARY KEY(ProjectID,MenuGroupCode),
        CONSTRAINT FK_TDADProjectMenuGroup_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT FK_TDADProjectMenuGroup_Group FOREIGN KEY(MenuGroupCode) REFERENCES dbo.TDADMenuGroup(MenuGroupCode)
    );
END;

IF OBJECT_ID(N'dbo.TDADProjectMenu',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADProjectMenu
    (
        ProjectID bigint NOT NULL,
        MenuCode char(5) NOT NULL,
        MenuGroupCode char(2) NOT NULL,
        SortOrder int NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADProjectMenu_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADProjectMenu_CreateDate DEFAULT(SYSDATETIME()),
        CreateBy bigint NULL, UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
        CONSTRAINT PK_TDADProjectMenu PRIMARY KEY(ProjectID,MenuCode),
        CONSTRAINT FK_TDADProjectMenu_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT FK_TDADProjectMenu_Menu FOREIGN KEY(MenuCode) REFERENCES dbo.TDADMainMenu(MenuCode),
        CONSTRAINT FK_TDADProjectMenu_ProjectGroup FOREIGN KEY(ProjectID,MenuGroupCode)
            REFERENCES dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode)
    );
    CREATE INDEX IX_TDADProjectMenu_Project_Group
        ON dbo.TDADProjectMenu(ProjectID,MenuGroupCode,SortOrder) INCLUDE(MenuCode,IsActive);
END;

DECLARE @CenterProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO');
DECLARE @MeetingProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MEETING');
IF @CenterProjectID IS NULL OR @MeetingProjectID IS NULL
    THROW 51000,'Required projects LAOO and LAOO_MEETING were not found.',1;

DECLARE @Groups TABLE
(
    MenuGroupCode char(2) PRIMARY KEY, MenuGroupName nvarchar(150), IconName nvarchar(100),
    SortOrder int, FeatureCode nvarchar(100)
);
INSERT @Groups VALUES
('21',N'ระบบจองห้องประชุม',N'event_available',90,N'MEETING_BOOKING'),
('22',N'การใช้งานห้องประชุม',N'sensor_door',100,N'MEETING_OPERATION'),
('23',N'ตั้งค่าห้องประชุม',N'settings_suggest',110,N'MEETING_SETUP'),
('24',N'รายงานห้องประชุม',N'analytics',120,N'MEETING_REPORT');

INSERT dbo.TDADMenuGroup
    (AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,FeatureCode)
SELECT N'C',g.MenuGroupCode,g.MenuGroupName,g.IconName,g.SortOrder,0,1,SYSDATETIME(),g.FeatureCode
FROM @Groups g
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup x WHERE x.MenuGroupCode=g.MenuGroupCode);

DECLARE @Menus TABLE
(
    MenuCode char(5) PRIMARY KEY, MenuGroupCode char(2), MenuName nvarchar(150), ScreenType int,
    RouteName nvarchar(150), RoutePath nvarchar(300), FeatureCode nvarchar(100), IconName nvarchar(100),
    SortOrder int, IsFavoriteAllowed bit
);
INSERT @Menus VALUES
('21001','21',N'จองห้องประชุม',1,N'meetingRoomBookings',N'/company/meeting-room-bookings',N'MEETING_ROOM_BOOKING',N'event_available',10,0),
('21002','21',N'ปฏิทินห้องประชุม',3,N'meetingRoomCalendar',N'/company/meeting-room-calendar',N'MEETING_ROOM_CALENDAR',N'calendar_month',20,0),
('21003','21',N'การเชิญของฉัน',2,N'meetingInvitationRsvp',N'/company/meeting-invitations',N'MEETING_INVITATION',N'mark_email_read',30,0),
('21004','21',N'รายการรออนุมัติห้องประชุม',2,N'meetingRoomApprovals',N'/company/meeting-room-approvals',N'MEETING_ROOM_APPROVAL',N'approval',4,1),
('21005','21',N'เมนูอาหารสำหรับการประชุม',1,N'meetingFoodPlans',N'/company/meeting-food-plans',N'MEETING_FOOD_PLAN',N'room_service',25,1),
('22001','22',N'เช็กอินและคืนห้อง',2,N'roomCheckIn',N'/company/room-check-in',N'ROOM_CHECK_IN',N'how_to_reg',10,0),
('22002','22',N'งานเตรียมห้องและอุปกรณ์',2,N'roomSupportTasks',N'/company/room-support-tasks',N'ROOM_SUPPORT_TASK',N'handyman',20,0),
('22003','22',N'แจ้งปัญหาห้องประชุม',1,N'roomIssues',N'/company/room-issues',N'ROOM_ISSUE',N'report_problem',30,0),
('23001','23',N'อาคารและชั้น',1,N'meetingBuildings',N'/company/meeting-buildings',N'MEETING_BUILDING',N'apartment',10,0),
('23002','23',N'ห้องประชุม',1,N'meetingRooms',N'/company/meeting-rooms',N'MEETING_ROOM',N'meeting_room',21,0),
('23003','23',N'อุปกรณ์ห้องประชุม',1,N'meetingFacilities',N'/company/meeting-facilities',N'MEETING_FACILITY',N'devices_other',20,0),
('23004','23',N'รายการอาหาร',1,N'meetingFoods',N'/company/meeting-foods',N'MEETING_FOOD',N'restaurant_menu',30,1),
('23005','23',N'กำหนดผู้บังคับบัญชา',2,N'companySupervisors',N'/company/supervisors',N'SUPERVISOR_ASSIGNMENT',N'supervisor_account',4,1),
('24001','24',N'รายงานการใช้ห้อง',3,N'meetingRoomUtilizationReport',N'/company/reports/meeting-room-utilization',N'MEETING_ROOM_UTILIZATION_REPORT',N'analytics',10,0),
('24002','24',N'รายงาน No-show',3,N'meetingNoShowReport',N'/company/reports/meeting-no-show',N'MEETING_NO_SHOW_REPORT',N'person_off',20,0),
('24003','24',N'ผลประเมินห้องประชุม',3,N'meetingFeedbackReport',N'/company/reports/meeting-feedback',N'MEETING_FEEDBACK_REPORT',N'reviews',30,0);

INSERT dbo.TDADMainMenu
    (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,
     SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate)
SELECT m.MenuCode,m.MenuGroupCode,m.MenuName,m.ScreenType,m.RouteName,m.RoutePath,m.FeatureCode,m.IconName,
       m.SortOrder,1,m.IsFavoriteAllowed,1,SYSDATETIME()
FROM @Menus m
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu x WHERE x.MenuCode=m.MenuCode);

INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive)
SELECT @CenterProjectID,g.MenuGroupCode,g.SortOrder,1
FROM dbo.TDADMenuGroup g
WHERE g.MenuGroupCode NOT IN('21','22','23','24')
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup x WHERE x.ProjectID=@CenterProjectID AND x.MenuGroupCode=g.MenuGroupCode);

INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT @CenterProjectID,m.MenuCode,m.MenuGroupCode,m.SortOrder,1
FROM dbo.TDADMainMenu m
WHERE m.MenuGroupCode NOT IN('21','22','23','24')
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu x WHERE x.ProjectID=@CenterProjectID AND x.MenuCode=m.MenuCode);

DECLARE @SharedMenus TABLE(MenuCode char(5) PRIMARY KEY);
INSERT @SharedMenus VALUES
('01001'),('01002'),('01003'),('01004'),('02001'),('02002'),('02003'),('03001'),('03002'),('03003'),
('04001'),('04002'),('05001'),('05002'),('06001'),('06002'),('07001'),('09002'),('10001'),('10003'),
('10004'),('10005'),('11001'),('11003'),('11004'),('11005'),('12001'),('12003'),('12004'),('12005');

INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive)
SELECT DISTINCT @MeetingProjectID,g.MenuGroupCode,g.SortOrder,1
FROM dbo.TDADMenuGroup g
JOIN
(
    SELECT m.MenuGroupCode FROM dbo.TDADMainMenu m JOIN @SharedMenus s ON s.MenuCode=m.MenuCode
    UNION SELECT MenuGroupCode FROM @Groups
) x ON x.MenuGroupCode=g.MenuGroupCode
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup p WHERE p.ProjectID=@MeetingProjectID AND p.MenuGroupCode=g.MenuGroupCode);

INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT @MeetingProjectID,m.MenuCode,m.MenuGroupCode,m.SortOrder,1
FROM dbo.TDADMainMenu m
WHERE (EXISTS(SELECT 1 FROM @SharedMenus s WHERE s.MenuCode=m.MenuCode)
       OR EXISTS(SELECT 1 FROM @Menus x WHERE x.MenuCode=m.MenuCode))
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu p WHERE p.ProjectID=@MeetingProjectID AND p.MenuCode=m.MenuCode);

DECLARE @AdminPermissionID bigint=(SELECT PermissionID FROM dbo.TDADPermission
    WHERE ProjectID=@MeetingProjectID AND ScreenCode=N'*' AND ActionCode=N'ADMIN');
IF @AdminPermissionID IS NULL
BEGIN
    INSERT dbo.TDADPermission
        (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    VALUES(@MeetingProjectID,N'*',N'ผู้ดูแลระบบ LAOO',N'LAOO Administrator',N'ADMIN',N'ผู้ดูแลระบบ',N'Administrator',1,SYSDATETIME());
    SET @AdminPermissionID=SCOPE_IDENTITY();
END;

INSERT dbo.TDADLaooUserPermission
    (LaooUserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedDate)
SELECT up.LaooUserID,@MeetingProjectID,@AdminPermissionID,1,1,N'LAOO_MEETING administrator',SYSDATETIME()
FROM dbo.TDADLaooUserProject up
JOIN dbo.TDADLaooUser u ON u.LaooUserID=up.LaooUserID AND u.IsSupportUser=1 AND u.IsActive=1
WHERE up.ProjectID=@MeetingProjectID AND up.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADLaooUserPermission x
      WHERE x.LaooUserID=up.LaooUserID AND x.ProjectID=@MeetingProjectID AND x.PermissionID=@AdminPermissionID);

COMMIT TRANSACTION;
GO
