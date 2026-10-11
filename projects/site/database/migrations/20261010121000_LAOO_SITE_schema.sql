SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSISetting',N'U') IS NOT NULL THROW 63101,N'SITE schema already exists',1;

CREATE TABLE dbo.TDSISetting(
 CompanyID bigint NOT NULL PRIMARY KEY,
 MaxPhotoMB int NOT NULL CONSTRAINT DF_TDSISetting_Photo DEFAULT(10),
 AllowOfflineDraft bit NOT NULL CONSTRAINT DF_TDSISetting_Offline DEFAULT(1),
 UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSISetting_Updated DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT CK_TDSISetting_Photo CHECK(MaxPhotoMB BETWEEN 1 AND 20));

CREATE TABLE dbo.TDSIProject(
 SiteProjectID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 BranchID bigint NULL,
 CustomerID bigint NOT NULL,
 ProjectCode nvarchar(40) NOT NULL,
 ProjectName nvarchar(200) NOT NULL,
 SiteAddress nvarchar(1000) NULL,
 Description nvarchar(2000) NULL,
 StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSIProject_Status DEFAULT(N'ACTIVE'),
 StartDate date NULL,
 DueDate date NULL,
 CreatedBy bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIProject_Created DEFAULT(SYSUTCDATETIME()),
 UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIProject_Updated DEFAULT(SYSUTCDATETIME()),
 RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDSIProject_CompanyID UNIQUE(CompanyID,SiteProjectID),
 CONSTRAINT UQ_TDSIProject_Code UNIQUE(CompanyID,ProjectCode),
 CONSTRAINT CK_TDSIProject_Status CHECK(StatusCode IN(N'ACTIVE',N'ON_HOLD',N'COMPLETED',N'CANCELLED')),
 CONSTRAINT CK_TDSIProject_Dates CHECK(DueDate IS NULL OR StartDate IS NULL OR DueDate>=StartDate));
CREATE INDEX IX_TDSIProject_Customer ON dbo.TDSIProject(CompanyID,CustomerID,StatusCode);

CREATE TABLE dbo.TDSITask(
 SiteTaskID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 TaskName nvarchar(200) NOT NULL,
 Weight decimal(9,4) NOT NULL,
 ProgressPercent decimal(5,2) NOT NULL CONSTRAINT DF_TDSITask_Progress DEFAULT(0),
 SortOrder int NOT NULL CONSTRAINT DF_TDSITask_Sort DEFAULT(0),
 IsActive bit NOT NULL CONSTRAINT DF_TDSITask_Active DEFAULT(1),
 UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSITask_Updated DEFAULT(SYSUTCDATETIME()),
 RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDSITask_CompanyID UNIQUE(CompanyID,SiteTaskID),
 CONSTRAINT FK_TDSITask_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT CK_TDSITask_Weight CHECK(Weight>0),
 CONSTRAINT CK_TDSITask_Progress CHECK(ProgressPercent BETWEEN 0 AND 100));

CREATE TABLE dbo.TDSIDailyReport(
 ReportID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 WorkDate date NOT NULL,
 Summary nvarchar(4000) NOT NULL,
 ProblemSummary nvarchar(4000) NULL,
 StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSIDailyReport_Status DEFAULT(N'DRAFT'),
 VersionNo int NOT NULL CONSTRAINT DF_TDSIDailyReport_Version DEFAULT(1),
 CreatedBy bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIDailyReport_Created DEFAULT(SYSUTCDATETIME()),
 SubmittedAt datetime2(3) NULL,
 ReviewedBy bigint NULL,
 ReviewedAt datetime2(3) NULL,
 ReviewReason nvarchar(1000) NULL,
 UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIDailyReport_Updated DEFAULT(SYSUTCDATETIME()),
 RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDSIDailyReport_CompanyID UNIQUE(CompanyID,ReportID),
 CONSTRAINT FK_TDSIDailyReport_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT CK_TDSIDailyReport_Status CHECK(StatusCode IN(N'DRAFT',N'SUBMITTED',N'RETURNED',N'REVIEWED',N'PUBLISHED')),
 CONSTRAINT CK_TDSIDailyReport_Version CHECK(VersionNo>0));
CREATE INDEX IX_TDSIDailyReport_ProjectDate ON dbo.TDSIDailyReport(CompanyID,SiteProjectID,WorkDate DESC);

CREATE TABLE dbo.TDSIDailyLine(
 LineID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 ReportID bigint NOT NULL,
 LineType nvarchar(20) NOT NULL,
 EmployeeID bigint NULL,
 ItemID bigint NULL,
 Description nvarchar(1000) NOT NULL,
 Quantity decimal(18,3) NULL,
 Amount decimal(18,2) NULL,
 SortOrder int NOT NULL CONSTRAINT DF_TDSIDailyLine_Sort DEFAULT(0),
 CONSTRAINT FK_TDSIDailyLine_Report FOREIGN KEY(CompanyID,ReportID) REFERENCES dbo.TDSIDailyReport(CompanyID,ReportID),
 CONSTRAINT CK_TDSIDailyLine_Type CHECK(LineType IN(N'WORKER',N'MATERIAL',N'EXPENSE')),
 CONSTRAINT CK_TDSIDailyLine_Quantity CHECK(Quantity IS NULL OR Quantity>0),
 CONSTRAINT CK_TDSIDailyLine_Amount CHECK(Amount IS NULL OR Amount>=0));

CREATE TABLE dbo.TDSIAttachment(
 AttachmentID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 ReportID bigint NULL,
 IssueID bigint NULL,
 HandoverID bigint NULL,
 FileName nvarchar(255) NOT NULL,
 StoredPath nvarchar(1000) NOT NULL,
 MimeType nvarchar(100) NOT NULL,
 FileBytes bigint NOT NULL,
 Sha256 char(64) NOT NULL,
 CreatedBy bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIAttachment_Created DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT UQ_TDSIAttachment_CompanyID UNIQUE(CompanyID,AttachmentID),
 CONSTRAINT FK_TDSIAttachment_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT FK_TDSIAttachment_Report FOREIGN KEY(CompanyID,ReportID) REFERENCES dbo.TDSIDailyReport(CompanyID,ReportID),
 CONSTRAINT CK_TDSIAttachment_Size CHECK(FileBytes>0));

CREATE TABLE dbo.TDSIIssue(
 IssueID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 ReportID bigint NULL,
 Title nvarchar(200) NOT NULL,
 Detail nvarchar(4000) NOT NULL,
 StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSIIssue_Status DEFAULT(N'OPEN'),
 AssignedEmployeeID bigint NULL,
 DueDate date NULL,
 Resolution nvarchar(4000) NULL,
 CreatedBy bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIIssue_Created DEFAULT(SYSUTCDATETIME()),
 UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIIssue_Updated DEFAULT(SYSUTCDATETIME()),
 RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDSIIssue_CompanyID UNIQUE(CompanyID,IssueID),
 CONSTRAINT FK_TDSIIssue_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT FK_TDSIIssue_Report FOREIGN KEY(CompanyID,ReportID) REFERENCES dbo.TDSIDailyReport(CompanyID,ReportID),
 CONSTRAINT CK_TDSIIssue_Status CHECK(StatusCode IN(N'OPEN',N'IN_PROGRESS',N'RESOLVED',N'CLOSED')));

CREATE TABLE dbo.TDSIPublication(
 PublicationID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 ReportID bigint NOT NULL,
 ReportVersionNo int NOT NULL,
 PublishedSnapshot nvarchar(max) NOT NULL,
 SnapshotSha256 char(64) NOT NULL,
 PublishedBy bigint NOT NULL,
 PublishedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIPublication_Published DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT UQ_TDSIPublication_CompanyID UNIQUE(CompanyID,PublicationID),
 CONSTRAINT UQ_TDSIPublication_ReportVersion UNIQUE(CompanyID,ReportID,ReportVersionNo),
 CONSTRAINT FK_TDSIPublication_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT FK_TDSIPublication_Report FOREIGN KEY(CompanyID,ReportID) REFERENCES dbo.TDSIDailyReport(CompanyID,ReportID),
 CONSTRAINT CK_TDSIPublication_Json CHECK(ISJSON(PublishedSnapshot)=1));

CREATE TABLE dbo.TDSIHandover(
 HandoverID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 HandoverNo nvarchar(40) NOT NULL,
 StageName nvarchar(200) NOT NULL,
 HandoverType nvarchar(20) NOT NULL,
 Detail nvarchar(4000) NOT NULL,
 StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSIHandover_Status DEFAULT(N'DRAFT'),
 SubmittedBy bigint NULL,
 SubmittedAt datetime2(3) NULL,
 AcceptedBy bigint NULL,
 AcceptedAt datetime2(3) NULL,
 ReturnReason nvarchar(1000) NULL,
 CreatedBy bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIHandover_Created DEFAULT(SYSUTCDATETIME()),
 UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIHandover_Updated DEFAULT(SYSUTCDATETIME()),
 RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDSIHandover_CompanyID UNIQUE(CompanyID,HandoverID),
 CONSTRAINT UQ_TDSIHandover_No UNIQUE(CompanyID,HandoverNo),
 CONSTRAINT FK_TDSIHandover_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT CK_TDSIHandover_Type CHECK(HandoverType IN(N'STAGE',N'FINAL')),
 CONSTRAINT CK_TDSIHandover_Status CHECK(StatusCode IN(N'DRAFT',N'SUBMITTED',N'ACCEPTED',N'RETURNED',N'CANCELLED')));

CREATE TABLE dbo.TDSICustomerAccount(
 CustomerAccountID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 CustomerID bigint NOT NULL,
 EmailNormalized nvarchar(320) NOT NULL,
 PasswordHash nvarchar(500) NOT NULL,
 IsActive bit NOT NULL CONSTRAINT DF_TDSICustomerAccount_Active DEFAULT(1),
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSICustomerAccount_Created DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT UQ_TDSICustomerAccount_CompanyID UNIQUE(CompanyID,CustomerAccountID),
 CONSTRAINT UQ_TDSICustomerAccount_Email UNIQUE(CompanyID,EmailNormalized));

CREATE TABLE dbo.TDSICustomerAccess(
 AccessID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 CustomerID bigint NOT NULL,
 CustomerAccountID bigint NOT NULL,
 IsActive bit NOT NULL CONSTRAINT DF_TDSICustomerAccess_Active DEFAULT(1),
 GrantedBy bigint NOT NULL,
 GrantedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSICustomerAccess_Granted DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT UQ_TDSICustomerAccess_CompanyID UNIQUE(CompanyID,AccessID),
 CONSTRAINT FK_TDSICustomerAccess_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT FK_TDSICustomerAccess_Account FOREIGN KEY(CompanyID,CustomerAccountID) REFERENCES dbo.TDSICustomerAccount(CompanyID,CustomerAccountID),
 CONSTRAINT UQ_TDSICustomerAccess_ProjectAccount UNIQUE(CompanyID,SiteProjectID,CustomerAccountID));
CREATE INDEX IX_TDSICustomerAccess_Identity ON dbo.TDSICustomerAccess(CompanyID,CustomerID,CustomerAccountID,IsActive);

CREATE TABLE dbo.TDSINotification(
 NotificationID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NOT NULL,
 AccessID bigint NOT NULL,
 NotificationType nvarchar(30) NOT NULL,
 ReferenceID bigint NOT NULL,
 Title nvarchar(200) NOT NULL,
 IsRead bit NOT NULL CONSTRAINT DF_TDSINotification_Read DEFAULT(0),
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSINotification_Created DEFAULT(SYSUTCDATETIME()),
 ReadAt datetime2(3) NULL,
 CONSTRAINT FK_TDSINotification_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT FK_TDSINotification_Access FOREIGN KEY(CompanyID,AccessID) REFERENCES dbo.TDSICustomerAccess(CompanyID,AccessID));

CREATE TABLE dbo.TDSIAudit(
 AuditID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CompanyID bigint NOT NULL,
 SiteProjectID bigint NULL,
 EntityType nvarchar(40) NOT NULL,
 EntityID bigint NOT NULL,
 ActionCode nvarchar(40) NOT NULL,
 ActorType nvarchar(30) NOT NULL,
 ActorID bigint NOT NULL,
 DetailJson nvarchar(max) NULL,
 CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSIAudit_Created DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT FK_TDSIAudit_Project FOREIGN KEY(CompanyID,SiteProjectID) REFERENCES dbo.TDSIProject(CompanyID,SiteProjectID),
 CONSTRAINT CK_TDSIAudit_Json CHECK(DetailJson IS NULL OR ISJSON(DetailJson)=1));
CREATE INDEX IX_TDSIAudit_Entity ON dbo.TDSIAudit(CompanyID,EntityType,EntityID,CreatedAt DESC);
ALTER TABLE dbo.TDSIAttachment ADD
 CONSTRAINT FK_TDSIAttachment_Issue FOREIGN KEY(CompanyID,IssueID) REFERENCES dbo.TDSIIssue(CompanyID,IssueID),
 CONSTRAINT FK_TDSIAttachment_Handover FOREIGN KEY(CompanyID,HandoverID) REFERENCES dbo.TDSIHandover(CompanyID,HandoverID),
 CONSTRAINT CK_TDSIAttachment_Owner CHECK(
  (CASE WHEN ReportID IS NULL THEN 0 ELSE 1 END)
 +(CASE WHEN IssueID IS NULL THEN 0 ELSE 1 END)
 +(CASE WHEN HandoverID IS NULL THEN 0 ELSE 1 END)=1);
GO
