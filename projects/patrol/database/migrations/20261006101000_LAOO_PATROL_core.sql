SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PATROL') THROW 57611,N'LAOO_PATROL bootstrap is required.',1;
IF OBJECT_ID(N'dbo.TDPCSetting',N'U') IS NULL CREATE TABLE dbo.TDPCSetting(
 CompanyID bigint NOT NULL PRIMARY KEY,ProjectID bigint NOT NULL,DefaultGraceBeforeMinutes int NOT NULL DEFAULT 0,
 DefaultGraceAfterMinutes int NOT NULL DEFAULT 15,OfflineMaxHours int NOT NULL DEFAULT 24,GpsRadiusMeters int NOT NULL DEFAULT 100,
 EscalateAfterMinutes int NOT NULL DEFAULT 30,CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),UpdatedAt datetime2(3) NULL,
 CONSTRAINT CK_TDPCSetting_Values CHECK(DefaultGraceBeforeMinutes BETWEEN 0 AND 1440 AND DefaultGraceAfterMinutes BETWEEN 0 AND 1440 AND OfflineMaxHours BETWEEN 1 AND 72 AND GpsRadiusMeters BETWEEN 5 AND 5000 AND EscalateAfterMinutes BETWEEN 1 AND 10080));
IF OBJECT_ID(N'dbo.TDPCCheckpoint',N'U') IS NULL CREATE TABLE dbo.TDPCCheckpoint(
 CheckpointID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,BranchID bigint NOT NULL,BuildingID bigint NULL,FloorID bigint NULL,RoomID bigint NULL,
 CheckpointCode nvarchar(30) NOT NULL,CheckpointName nvarchar(150) NOT NULL,TimeMode nvarchar(20) NOT NULL DEFAULT N'ANYTIME_IN_RUN',
 Latitude decimal(10,7) NULL,Longitude decimal(10,7) NULL,GpsRadiusMeters int NULL,RequireGps bit NOT NULL DEFAULT 0,RequirePhoto bit NOT NULL DEFAULT 0,
 RequireChecklist bit NOT NULL DEFAULT 0,AllowedMethods nvarchar(200) NOT NULL DEFAULT N'CARD,QR,NFC,FINGERPRINT,FACE',TokenVersion int NOT NULL DEFAULT 1,
 IsActive bit NOT NULL DEFAULT 1,CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),UpdatedAt datetime2(3) NULL,
 CONSTRAINT UQ_TDPCCheckpoint_Code UNIQUE(CompanyID,CheckpointCode),CONSTRAINT CK_TDPCCheckpoint_TimeMode CHECK(TimeMode IN(N'TIME_WINDOW',N'ANYTIME_IN_RUN')));
IF OBJECT_ID(N'dbo.TDPCDevice',N'U') IS NULL CREATE TABLE dbo.TDPCDevice(
 DeviceID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,CheckpointID bigint NULL,DeviceCode nvarchar(50) NOT NULL,DeviceName nvarchar(150) NOT NULL,
 AdapterCode nvarchar(30) NOT NULL,PublicKey nvarchar(2000) NULL,LastSequence bigint NOT NULL DEFAULT 0,LastSeenAt datetime2(3) NULL,IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),CONSTRAINT UQ_TDPCDevice_Code UNIQUE(CompanyID,DeviceCode));
IF OBJECT_ID(N'dbo.TDPCCredential',N'U') IS NULL CREATE TABLE dbo.TDPCCredential(
 CredentialID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,EmployeeID bigint NOT NULL,CredentialType nvarchar(20) NOT NULL,
 CredentialRefHash varbinary(32) NOT NULL,CredentialHint nvarchar(100) NULL,DeviceID bigint NULL,IsActive bit NOT NULL DEFAULT 1,
 EnrolledAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),RevokedAt datetime2(3) NULL,
 CONSTRAINT UQ_TDPCCredential_Ref UNIQUE(CompanyID,CredentialType,CredentialRefHash),CONSTRAINT CK_TDPCCredential_Type CHECK(CredentialType IN(N'CARD',N'QR',N'NFC',N'FINGERPRINT',N'FACE')));
IF OBJECT_ID(N'dbo.TDPCChecklistTemplate',N'U') IS NULL CREATE TABLE dbo.TDPCChecklistTemplate(
 TemplateID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,TemplateCode nvarchar(30) NOT NULL,TemplateName nvarchar(150) NOT NULL,WorkType nvarchar(30) NOT NULL,
 IsActive bit NOT NULL DEFAULT 1,CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),CONSTRAINT UQ_TDPCChecklistTemplate_Code UNIQUE(CompanyID,TemplateCode));
IF OBJECT_ID(N'dbo.TDPCChecklistItem',N'U') IS NULL CREATE TABLE dbo.TDPCChecklistItem(
 ItemID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,TemplateID bigint NOT NULL,SequenceNo int NOT NULL,ItemText nvarchar(300) NOT NULL,
 ResponseType nvarchar(20) NOT NULL DEFAULT N'PASS_FAIL',IsRequired bit NOT NULL DEFAULT 1,CONSTRAINT UQ_TDPCChecklistItem_Seq UNIQUE(CompanyID,TemplateID,SequenceNo));
IF OBJECT_ID(N'dbo.TDPCRoute',N'U') IS NULL CREATE TABLE dbo.TDPCRoute(
 RouteID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,BranchID bigint NOT NULL,RouteCode nvarchar(30) NOT NULL,RouteName nvarchar(150) NOT NULL,
 WorkType nvarchar(30) NOT NULL,SequenceMode nvarchar(20) NOT NULL DEFAULT N'FLEXIBLE',IsActive bit NOT NULL DEFAULT 1,CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_TDPCRoute_Code UNIQUE(CompanyID,RouteCode),CONSTRAINT CK_TDPCRoute_Sequence CHECK(SequenceMode IN(N'STRICT',N'FLEXIBLE')));
IF OBJECT_ID(N'dbo.TDPCRouteCheckpoint',N'U') IS NULL CREATE TABLE dbo.TDPCRouteCheckpoint(
 RouteCheckpointID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,RouteID bigint NOT NULL,CheckpointID bigint NOT NULL,SequenceNo int NOT NULL,
 TimeMode nvarchar(20) NOT NULL,WindowStart time(0) NULL,WindowEnd time(0) NULL,GraceBeforeMinutes int NOT NULL DEFAULT 0,GraceAfterMinutes int NOT NULL DEFAULT 15,
 ChecklistTemplateID bigint NULL,CONSTRAINT UQ_TDPCRouteCheckpoint_Seq UNIQUE(CompanyID,RouteID,SequenceNo),
 CONSTRAINT CK_TDPCRouteCheckpoint_Window CHECK((TimeMode=N'ANYTIME_IN_RUN' AND WindowStart IS NULL AND WindowEnd IS NULL) OR (TimeMode=N'TIME_WINDOW' AND WindowStart IS NOT NULL AND WindowEnd IS NOT NULL)));
IF OBJECT_ID(N'dbo.TDPCSchedule',N'U') IS NULL CREATE TABLE dbo.TDPCSchedule(
 ScheduleID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,RouteID bigint NOT NULL,ScheduleCode nvarchar(30) NOT NULL,ScheduleName nvarchar(150) NOT NULL,
 StartsAt datetime2(3) NOT NULL,EndsAt datetime2(3) NOT NULL,AssignedEmployeeID bigint NULL,AssignedTeamCode nvarchar(50) NULL,StatusCode nvarchar(20) NOT NULL DEFAULT N'PLANNED',
 CreatedBy bigint NOT NULL,CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),CONSTRAINT UQ_TDPCSchedule_Code UNIQUE(CompanyID,ScheduleCode),
 CONSTRAINT CK_TDPCSchedule_Time CHECK(StartsAt<EndsAt),CONSTRAINT CK_TDPCSchedule_Assignee CHECK(AssignedEmployeeID IS NOT NULL OR AssignedTeamCode IS NOT NULL));
IF OBJECT_ID(N'dbo.TDPCRun',N'U') IS NULL CREATE TABLE dbo.TDPCRun(
 RunID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ScheduleID bigint NOT NULL,RouteID bigint NOT NULL,RouteNameSnapshot nvarchar(150) NOT NULL,
 AssignedEmployeeID bigint NULL,AssignedTeamCode nvarchar(50) NULL,StartsAt datetime2(3) NOT NULL,EndsAt datetime2(3) NOT NULL,StatusCode nvarchar(20) NOT NULL DEFAULT N'OPEN',
 StartedAt datetime2(3) NULL,CompletedAt datetime2(3) NULL,CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),CONSTRAINT UQ_TDPCRun_Schedule UNIQUE(CompanyID,ScheduleID));
IF OBJECT_ID(N'dbo.TDPCRunCheckpoint',N'U') IS NULL CREATE TABLE dbo.TDPCRunCheckpoint(
 RunCheckpointID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,RunID bigint NOT NULL,CheckpointID bigint NOT NULL,SequenceNo int NOT NULL,
 CheckpointCodeSnapshot nvarchar(30) NOT NULL,CheckpointNameSnapshot nvarchar(150) NOT NULL,TimeMode nvarchar(20) NOT NULL,ScheduledFrom datetime2(3) NULL,ScheduledTo datetime2(3) NULL,
 GraceBeforeMinutes int NOT NULL,GraceAfterMinutes int NOT NULL,RequireGps bit NOT NULL,RequirePhoto bit NOT NULL,RequireChecklist bit NOT NULL,
 StatusCode nvarchar(20) NOT NULL DEFAULT N'PENDING',CheckedAt datetime2(3) NULL,CheckedByEmployeeID bigint NULL,MinutesVariance int NULL,
 CONSTRAINT UQ_TDPCRunCheckpoint_Seq UNIQUE(CompanyID,RunID,SequenceNo));
IF OBJECT_ID(N'dbo.TDPCCheckEvent',N'U') IS NULL CREATE TABLE dbo.TDPCCheckEvent(
 CheckEventID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,RunID bigint NOT NULL,RunCheckpointID bigint NOT NULL,EmployeeID bigint NOT NULL,
 EventKey uniqueidentifier NOT NULL,MethodCode nvarchar(20) NOT NULL,OccurredAt datetime2(3) NOT NULL,ReceivedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 DeviceID bigint NULL,DeviceSequence bigint NULL,Latitude decimal(10,7) NULL,Longitude decimal(10,7) NULL,GpsAccuracyMeters decimal(10,2) NULL,
 IsOffline bit NOT NULL DEFAULT 0,PhotoPath nvarchar(500) NULL,ChecklistJson nvarchar(max) NULL,Note nvarchar(1000) NULL,ResultCode nvarchar(20) NOT NULL,
 CONSTRAINT UQ_TDPCCheckEvent_Key UNIQUE(CompanyID,EventKey),CONSTRAINT CK_TDPCCheckEvent_Method CHECK(MethodCode IN(N'CARD',N'QR',N'NFC',N'FINGERPRINT',N'FACE',N'SIMULATOR')));
IF OBJECT_ID(N'dbo.TDPCIncident',N'U') IS NULL CREATE TABLE dbo.TDPCIncident(
 IncidentID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,RunID bigint NOT NULL,RunCheckpointID bigint NULL,IncidentCode nvarchar(30) NOT NULL,
 SeverityCode nvarchar(20) NOT NULL,Subject nvarchar(200) NOT NULL,Detail nvarchar(2000) NOT NULL,StatusCode nvarchar(20) NOT NULL DEFAULT N'OPEN',
 ServiceRequestID bigint NULL,ReportedBy bigint NOT NULL,ReportedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),AcknowledgedAt datetime2(3) NULL,ResolvedAt datetime2(3) NULL,
 CONSTRAINT UQ_TDPCIncident_Code UNIQUE(CompanyID,IncidentCode));
IF OBJECT_ID(N'dbo.TDPCAudit',N'U') IS NULL CREATE TABLE dbo.TDPCAudit(
 AuditID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ActorUserID bigint NULL,ActorEmployeeID bigint NULL,ActionCode nvarchar(50) NOT NULL,
 EntityType nvarchar(40) NOT NULL,EntityID bigint NOT NULL,Detail nvarchar(1500) NULL,CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPCRun') AND name=N'IX_TDPCRun_StatusTime') CREATE INDEX IX_TDPCRun_StatusTime ON dbo.TDPCRun(CompanyID,StatusCode,StartsAt,EndsAt);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPCCheckEvent') AND name=N'IX_TDPCCheckEvent_Run') CREATE INDEX IX_TDPCCheckEvent_Run ON dbo.TDPCCheckEvent(CompanyID,RunID,OccurredAt);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPCIncident') AND name=N'IX_TDPCIncident_Status') CREATE INDEX IX_TDPCIncident_Status ON dbo.TDPCIncident(CompanyID,StatusCode,ReportedAt);
