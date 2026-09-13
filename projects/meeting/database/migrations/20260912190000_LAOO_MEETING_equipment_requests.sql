SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADMeetingBookingEquipmentPlan',N'U') IS NULL
CREATE TABLE dbo.TDADMeetingBookingEquipmentPlan
(
 BookingID bigint NOT NULL CONSTRAINT PK_TDADMeetingBookingEquipmentPlan PRIMARY KEY,
 CompanyID bigint NOT NULL, RequestCutoffDateTime datetime2(3) NOT NULL, IsActive bit NOT NULL CONSTRAINT DF_TDADMeetingBookingEquipmentPlan_IsActive DEFAULT 1,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADMeetingBookingEquipmentPlan_CreateDate DEFAULT SYSUTCDATETIME(), CreateBy bigint NULL,
 UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
 CONSTRAINT FK_TDADMeetingBookingEquipmentPlan_Booking FOREIGN KEY(BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID)
);

IF OBJECT_ID(N'dbo.TDADMeetingBookingEquipmentRequest',N'U') IS NULL
CREATE TABLE dbo.TDADMeetingBookingEquipmentRequest
(
 EquipmentRequestID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingEquipmentRequest PRIMARY KEY,
 CompanyID bigint NOT NULL, BookingID bigint NOT NULL, RequestedByUserID bigint NOT NULL,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADMeetingBookingEquipmentRequest_CreateDate DEFAULT SYSUTCDATETIME(),
 UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
 CONSTRAINT FK_TDADMeetingBookingEquipmentRequest_Booking FOREIGN KEY(BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID)
);

IF OBJECT_ID(N'dbo.TDADMeetingBookingEquipmentRequestDetail',N'U') IS NULL
CREATE TABLE dbo.TDADMeetingBookingEquipmentRequestDetail
(
 EquipmentRequestDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingEquipmentRequestDetail PRIMARY KEY,
 EquipmentRequestID bigint NOT NULL, CompanyID bigint NOT NULL, ItemID bigint NOT NULL, ResponsibleDepartmentOrgUnitID bigint NOT NULL,
 Quantity decimal(18,2) NOT NULL, Remark nvarchar(500) NULL, StatusCode varchar(20) NOT NULL CONSTRAINT DF_TDADMeetingBookingEquipmentRequestDetail_Status DEFAULT 'PENDING',
 ProcessedByUserID bigint NULL, ProcessedDateTime datetime2(3) NULL, ResultRemark nvarchar(500) NULL,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADMeetingBookingEquipmentRequestDetail_CreateDate DEFAULT SYSUTCDATETIME(), UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
 CONSTRAINT FK_TDADMeetingBookingEquipmentRequestDetail_Header FOREIGN KEY(EquipmentRequestID) REFERENCES dbo.TDADMeetingBookingEquipmentRequest(EquipmentRequestID),
 CONSTRAINT FK_TDADMeetingBookingEquipmentRequestDetail_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
 CONSTRAINT CK_TDADMeetingBookingEquipmentRequestDetail_Quantity CHECK(Quantity>0),
 CONSTRAINT CK_TDADMeetingBookingEquipmentRequestDetail_Status CHECK(StatusCode IN('PENDING','IN_PROGRESS','COMPLETED','REJECTED','CANCELLED'))
);

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_TDADMeetingBookingEquipmentRequest_Company_Booking') CREATE INDEX IX_TDADMeetingBookingEquipmentRequest_Company_Booking ON dbo.TDADMeetingBookingEquipmentRequest(CompanyID,BookingID);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_TDADMeetingBookingEquipmentRequestDetail_Department_Status') CREATE INDEX IX_TDADMeetingBookingEquipmentRequestDetail_Department_Status ON dbo.TDADMeetingBookingEquipmentRequestDetail(CompanyID,ResponsibleDepartmentOrgUnitID,StatusCode);

DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MEETING' AND IsActive=1);
IF @ProjectID IS NULL THROW 51000,'Active LAOO_MEETING project was not found.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode='22005')
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate)
 VALUES('22005','22',N'คำขออุปกรณ์เพิ่มเติม',2,N'meetingEquipmentRequests',N'/company/meeting-equipment-requests',N'MEETING_EQUIPMENT_REQUEST',N'handyman',20,1,1,1,SYSDATETIME());
ELSE UPDATE dbo.TDADMainMenu SET MenuGroupCode='22',MenuName=N'คำขออุปกรณ์เพิ่มเติม',ScreenType=2,RouteName=N'meetingEquipmentRequests',RoutePath=N'/company/meeting-equipment-requests',FeatureCode=N'MEETING_EQUIPMENT_REQUEST',IconName=N'handyman',SortOrder=20,IsVisible=1,IsActive=1,UpdateDate=SYSDATETIME() WHERE MenuCode='22005';
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode='22005') INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive) VALUES(@ProjectID,'22005','22',20,1);
ELSE UPDATE dbo.TDADProjectMenu SET MenuGroupCode='22',SortOrder=20,IsActive=1 WHERE ProjectID=@ProjectID AND MenuCode='22005';
DECLARE @P TABLE(ActionCode varchar(20),ActionNameTH nvarchar(100),ActionNameEN nvarchar(100));
INSERT @P VALUES('VIEW',N'ดูข้อมูล',N'View'),('EDIT',N'แก้ไขข้อมูล',N'Edit');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,'22005',N'คำขออุปกรณ์เพิ่มเติม',N'Meeting equipment requests',P.ActionCode,P.ActionNameTH,P.ActionNameEN,1,SYSDATETIME() FROM @P P
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission X WHERE X.ProjectID=@ProjectID AND X.ScreenCode='22005' AND X.ActionCode=P.ActionCode);
COMMIT TRANSACTION;
GO
