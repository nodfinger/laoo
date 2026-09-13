SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDSTCompanySetupSystemMeeting',N'U') IS NULL
CREATE TABLE dbo.TDSTCompanySetupSystemMeeting
(
 CompanyID bigint NOT NULL,
 ProjectID bigint NOT NULL,
 RequireEquipmentRequestReview bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemMeeting_RequireReview DEFAULT(0),
 CreateBy bigint NULL, CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemMeeting_CreateDate DEFAULT SYSUTCDATETIME(),
 UpdateBy bigint NULL, UpdateDate datetime2(3) NULL,
 CONSTRAINT PK_TDSTCompanySetupSystemMeeting PRIMARY KEY(CompanyID,ProjectID)
);

IF COL_LENGTH(N'dbo.TDADMeetingBookingEquipmentRequest',N'RequestedByName') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingEquipmentRequest ADD RequestedByName nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDADMeetingBookingEquipmentRequest',N'RequestedByRoleCode') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingEquipmentRequest ADD RequestedByRoleCode varchar(30) NULL;
IF COL_LENGTH(N'dbo.TDADMeetingBookingEquipmentRequest',N'RequiresReview') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingEquipmentRequest ADD RequiresReview bit NOT NULL CONSTRAINT DF_TDADMeetingBookingEquipmentRequest_RequiresReview DEFAULT(0);

IF COL_LENGTH(N'dbo.TDADMeetingBookingEquipmentRequestDetail',N'ReviewedByUserID') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingEquipmentRequestDetail ADD ReviewedByUserID bigint NULL, ReviewedByName nvarchar(200) NULL, ReviewedDateTime datetime2(3) NULL, ReviewRemark nvarchar(500) NULL;

UPDATE dbo.TDADMeetingBookingEquipmentRequestDetail SET StatusCode='DEPARTMENT_REJECTED' WHERE StatusCode='REJECTED';
DECLARE @checkName sysname=(SELECT TOP(1) name FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADMeetingBookingEquipmentRequestDetail') AND definition LIKE '%StatusCode%');
IF @checkName IS NOT NULL EXEC(N'ALTER TABLE dbo.TDADMeetingBookingEquipmentRequestDetail DROP CONSTRAINT '+QUOTENAME(@checkName));
ALTER TABLE dbo.TDADMeetingBookingEquipmentRequestDetail ADD CONSTRAINT CK_TDADMeetingBookingEquipmentRequestDetail_Status CHECK(StatusCode IN('WAITING_REVIEW','REVIEW_REJECTED','PENDING','IN_PROGRESS','COMPLETED','DEPARTMENT_REJECTED','CANCELLED'));

IF OBJECT_ID(N'dbo.TDADMeetingBookingEquipmentRequestTimeline',N'U') IS NULL
CREATE TABLE dbo.TDADMeetingBookingEquipmentRequestTimeline
(
 EquipmentRequestTimelineID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingEquipmentRequestTimeline PRIMARY KEY,
 CompanyID bigint NOT NULL, EquipmentRequestID bigint NOT NULL, EquipmentRequestDetailID bigint NULL,
 EventCode varchar(30) NOT NULL, EventRemark nvarchar(500) NULL, ActorUserID bigint NULL, ActorName nvarchar(200) NULL,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADMeetingBookingEquipmentRequestTimeline_CreateDate DEFAULT SYSUTCDATETIME(),
 CONSTRAINT FK_TDADMeetingBookingEquipmentRequestTimeline_Header FOREIGN KEY(EquipmentRequestID) REFERENCES dbo.TDADMeetingBookingEquipmentRequest(EquipmentRequestID)
);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_TDADMeetingBookingEquipmentRequestTimeline_Request')
 CREATE INDEX IX_TDADMeetingBookingEquipmentRequestTimeline_Request ON dbo.TDADMeetingBookingEquipmentRequestTimeline(CompanyID,EquipmentRequestID,CreateDate);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_TDADMeetingBookingEquipmentRequestDetail_Status')
 CREATE INDEX IX_TDADMeetingBookingEquipmentRequestDetail_Status ON dbo.TDADMeetingBookingEquipmentRequestDetail(CompanyID,StatusCode,ResponsibleDepartmentOrgUnitID);

COMMIT TRANSACTION;
GO