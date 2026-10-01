SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTCompanySetupSystemIntranet',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSTCompanySetupSystemIntranet(
  CompanyID bigint NOT NULL CONSTRAINT PK_TDSTCompanySetupSystemIntranet PRIMARY KEY,
  ProjectID bigint NOT NULL,
  IsEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_Enabled DEFAULT(1),
  RequireApproval bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_Approval DEFAULT(1),
  AllowSelfApproval bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_SelfApproval DEFAULT(0),
  DefaultApproverEmployeeID bigint NULL,
  DefaultPublishDays int NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_PublishDays DEFAULT(30),
  CreateBy bigint NULL,
  CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_CreateDate DEFAULT(SYSUTCDATETIME()),
  UpdateBy bigint NULL,
  UpdateDate datetime2 NULL,
  CONSTRAINT CK_TDSTCompanySetupSystemIntranet_PublishDays CHECK(DefaultPublishDays BETWEEN 1 AND 3650)
 );
END;

IF OBJECT_ID(N'dbo.TDINContent',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDINContent(
  ContentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDINContent PRIMARY KEY,
  CompanyID bigint NOT NULL,
  ProjectID bigint NOT NULL,
  ContentCode nvarchar(40) NOT NULL,
  ContentTypeCode nvarchar(20) NOT NULL,
  Title nvarchar(250) NOT NULL,
  SummaryText nvarchar(1000) NULL,
  BodyText nvarchar(max) NULL,
  SourceUrl nvarchar(1000) NULL,
  TargetMode nvarchar(20) NOT NULL CONSTRAINT DF_TDINContent_TargetMode DEFAULT(N'ALL'),
  IsPinned bit NOT NULL CONSTRAINT DF_TDINContent_Pinned DEFAULT(0),
  RequiresAcknowledgement bit NOT NULL CONSTRAINT DF_TDINContent_Ack DEFAULT(0),
  PublishAt datetime2 NOT NULL,
  ExpireAt datetime2 NULL,
  ApproverEmployeeID bigint NULL,
  StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDINContent_Status DEFAULT(N'DRAFT'),
  ReturnReason nvarchar(1000) NULL,
  SubmittedAt datetime2 NULL,
  ApprovedAt datetime2 NULL,
  PublishedAt datetime2 NULL,
  ClosedAt datetime2 NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDINContent_Active DEFAULT(1),
  CreateBy bigint NULL,
  CreateDate datetime2 NOT NULL CONSTRAINT DF_TDINContent_CreateDate DEFAULT(SYSUTCDATETIME()),
  UpdateBy bigint NULL,
  UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDINContent_Code UNIQUE(CompanyID,ContentCode),
  CONSTRAINT CK_TDINContent_Type CHECK(ContentTypeCode IN(N'NEWS',N'ANNOUNCEMENT',N'ACTIVITY',N'DOCUMENT')),
  CONSTRAINT CK_TDINContent_TargetMode CHECK(TargetMode IN(N'ALL',N'DEPARTMENT',N'EMPLOYEE')),
  CONSTRAINT CK_TDINContent_Status CHECK(StatusCode IN(N'DRAFT',N'PENDING_APPROVAL',N'RETURNED',N'APPROVED',N'PUBLISHED',N'CLOSED',N'CANCELLED')),
  CONSTRAINT CK_TDINContent_Date CHECK(ExpireAt IS NULL OR PublishAt<ExpireAt)
 );
 CREATE INDEX IX_TDINContent_CompanyStatus ON dbo.TDINContent(CompanyID,StatusCode,PublishAt,ExpireAt);
END;

IF OBJECT_ID(N'dbo.TDINContentTargetDepartment',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDINContentTargetDepartment(
  ContentTargetDepartmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDINContentTargetDepartment PRIMARY KEY,
  CompanyID bigint NOT NULL,ContentID bigint NOT NULL,DepartmentOrgUnitID bigint NOT NULL,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDINContentTargetDepartment_CreateDate DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDINContentTargetDepartment_Content FOREIGN KEY(ContentID) REFERENCES dbo.TDINContent(ContentID) ON DELETE CASCADE,
  CONSTRAINT UQ_TDINContentTargetDepartment UNIQUE(ContentID,DepartmentOrgUnitID)
 );
END;

IF OBJECT_ID(N'dbo.TDINContentTargetEmployee',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDINContentTargetEmployee(
  ContentTargetEmployeeID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDINContentTargetEmployee PRIMARY KEY,
  CompanyID bigint NOT NULL,ContentID bigint NOT NULL,EmployeeID bigint NOT NULL,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDINContentTargetEmployee_CreateDate DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDINContentTargetEmployee_Content FOREIGN KEY(ContentID) REFERENCES dbo.TDINContent(ContentID) ON DELETE CASCADE,
  CONSTRAINT UQ_TDINContentTargetEmployee UNIQUE(ContentID,EmployeeID)
 );
END;

IF OBJECT_ID(N'dbo.TDINContentReceipt',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDINContentReceipt(
  ContentReceiptID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDINContentReceipt PRIMARY KEY,
  CompanyID bigint NOT NULL,ContentID bigint NOT NULL,UserID bigint NOT NULL,
  FirstReadAt datetime2 NOT NULL CONSTRAINT DF_TDINContentReceipt_FirstRead DEFAULT(SYSUTCDATETIME()),
  LastReadAt datetime2 NOT NULL CONSTRAINT DF_TDINContentReceipt_LastRead DEFAULT(SYSUTCDATETIME()),
  AcknowledgedAt datetime2 NULL,
  CONSTRAINT FK_TDINContentReceipt_Content FOREIGN KEY(ContentID) REFERENCES dbo.TDINContent(ContentID) ON DELETE CASCADE,
  CONSTRAINT UQ_TDINContentReceipt UNIQUE(CompanyID,ContentID,UserID)
 );
 CREATE INDEX IX_TDINContentReceipt_User ON dbo.TDINContentReceipt(CompanyID,UserID,AcknowledgedAt);
END;

IF OBJECT_ID(N'dbo.TDINContentApprovalHistory',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDINContentApprovalHistory(
  ContentApprovalHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDINContentApprovalHistory PRIMARY KEY,
  CompanyID bigint NOT NULL,ContentID bigint NOT NULL,ActionCode nvarchar(30) NOT NULL,
  FromStatusCode nvarchar(30) NULL,ToStatusCode nvarchar(30) NOT NULL,ReasonText nvarchar(1000) NULL,
  ActionBy bigint NOT NULL,ActionAt datetime2 NOT NULL CONSTRAINT DF_TDINContentApprovalHistory_ActionAt DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDINContentApprovalHistory_Content FOREIGN KEY(ContentID) REFERENCES dbo.TDINContent(ContentID) ON DELETE CASCADE
 );
END;

DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_INTRANET' AND IsActive=1);
IF @ProjectID IS NULL THROW 54300,N'LAOO_INTRANET project is missing.',1;

UPDATE dbo.TDADMainMenu
SET ScreenType=2,UpdateBy=0,UpdateDate=SYSUTCDATETIME()
WHERE MenuCode=N'43003' AND ScreenType<>2;

UPDATE PM SET IsActive=1,UpdateBy=0,UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADProjectMenu PM
WHERE PM.ProjectID=@ProjectID AND PM.MenuCode BETWEEN N'43001' AND N'43005';

DECLARE @Actions TABLE(MenuCode nvarchar(20),ActionCode nvarchar(30),NameTH nvarchar(100),NameEN nvarchar(100));
INSERT @Actions VALUES
(N'43001',N'EDIT',N'แก้ไข',N'Edit'),
(N'43002',N'CREATE',N'เพิ่ม',N'Create'),
(N'43002',N'EDIT',N'แก้ไข',N'Edit'),
(N'43002',N'DELETE',N'ลบ',N'Delete'),
(N'43002',N'SUBMIT',N'ส่งอนุมัติ',N'Submit'),
(N'43003',N'APPROVE',N'อนุมัติ',N'Approve'),
(N'43003',N'RETURN',N'ส่งกลับแก้ไข',N'Return');

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,a.MenuCode,m.MenuName,N'Intranet',a.ActionCode,a.NameTH,a.NameEN,1,SYSUTCDATETIME()
FROM @Actions a JOIN dbo.TDADMainMenu m ON m.MenuCode=a.MenuCode
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission p WHERE p.ProjectID=@ProjectID AND p.ScreenCode=a.MenuCode AND p.ActionCode=a.ActionCode);

UPDATE p SET IsActive=1,ModifiedDate=SYSUTCDATETIME()
FROM dbo.TDADPermission p JOIN @Actions a ON a.MenuCode=p.ScreenCode AND a.ActionCode=p.ActionCode
WHERE p.ProjectID=@ProjectID;
