SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMVisitorAppointment', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDTMVisitorAppointment
 (
  VisitorAppointmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMVisitorAppointment PRIMARY KEY,
  CompanyID bigint NOT NULL, BranchID bigint NULL, VisitorName nvarchar(200) NOT NULL, Phone nvarchar(50) NULL,
  AppointmentDate datetime2(3) NOT NULL, VisitPurpose nvarchar(1000) NULL,
  HostType varchar(20) NOT NULL, HostEmployeeID bigint NULL, HostResidentID bigint NULL, HostServiceCustomerID bigint NULL, HostTenantContactID bigint NULL,
  HostNameSnapshot nvarchar(200) NOT NULL, ContactPointNameSnapshot nvarchar(200) NULL,
  StatusCode varchar(20) NOT NULL CONSTRAINT DF_TDTMVisitorAppointment_Status DEFAULT('PENDING'),
  ApprovalNote nvarchar(1000) NULL, ApprovedByUserID bigint NULL, ApprovedByNameSnapshot nvarchar(200) NULL, ApprovedDate datetime2(3) NULL,
  UsedVisitorVisitID bigint NULL, CancelledDate datetime2(3) NULL, CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorAppointment_CreateDate DEFAULT(SYSUTCDATETIME()), CreateBy bigint NOT NULL,
  UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
  CONSTRAINT CK_TDTMVisitorAppointment_Status CHECK(StatusCode IN('PENDING','APPROVED','REJECTED','CANCELLED','USED'))
 );
 CREATE INDEX IX_TDTMVisitorAppointment_Host ON dbo.TDTMVisitorAppointment(CompanyID,HostType,StatusCode,AppointmentDate);
 CREATE INDEX IX_TDTMVisitorAppointment_Lookup ON dbo.TDTMVisitorAppointment(CompanyID,StatusCode,AppointmentDate,VisitorName,Phone);
END;
IF OBJECT_ID(N'dbo.TDTMVisitorAppointmentAudit', N'U') IS NULL
 CREATE TABLE dbo.TDTMVisitorAppointmentAudit
 (VisitorAppointmentAuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMVisitorAppointmentAudit PRIMARY KEY, CompanyID bigint NOT NULL, VisitorAppointmentID bigint NOT NULL, FromStatusCode varchar(20) NULL, ToStatusCode varchar(20) NOT NULL, NoteText nvarchar(1000) NULL, ActorUserID bigint NOT NULL, ActorNameSnapshot nvarchar(200) NULL, OccurredDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMVisitorAppointmentAudit_OccurredDate DEFAULT(SYSUTCDATETIME()));
COMMIT TRANSACTION;
