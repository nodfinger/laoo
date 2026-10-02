SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'dbo.TDDCSystemSetting',N'U') IS NULL CREATE TABLE dbo.TDDCSystemSetting(
  CompanyID bigint NOT NULL PRIMARY KEY,MaxPrimaryFileMB int NOT NULL CONSTRAINT DF_TDDCSetting_Primary DEFAULT(20),MaxAttachmentFileMB int NOT NULL CONSTRAINT DF_TDDCSetting_Attachment DEFAULT(20),
  AllowedAttachmentExtensions nvarchar(500) NOT NULL CONSTRAINT DF_TDDCSetting_Ext DEFAULT(N'pdf,doc,docx,xls,xlsx,ppt,pptx,jpg,jpeg,png'),ReminderDays int NOT NULL CONSTRAINT DF_TDDCSetting_Reminder DEFAULT(3),
  CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCSetting_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT CK_TDDCSetting_Size CHECK(MaxPrimaryFileMB BETWEEN 1 AND 100 AND MaxAttachmentFileMB BETWEEN 1 AND 100));
 IF OBJECT_ID(N'dbo.TDDCDocumentType',N'U') IS NULL CREATE TABLE dbo.TDDCDocumentType(
  DocumentTypeID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,TypeCode nvarchar(30) NOT NULL,TypeName nvarchar(200) NOT NULL,DocumentClass nvarchar(20) NOT NULL,
  RequireAcknowledgement bit NOT NULL CONSTRAINT DF_TDDCType_Ack DEFAULT(0),DefaultReviewerUserID bigint NULL,DefaultApproverUserID bigint NULL,DefaultAudienceMode nvarchar(20) NOT NULL CONSTRAINT DF_TDDCType_Audience DEFAULT(N'ALL'),
  IsActive bit NOT NULL CONSTRAINT DF_TDDCType_Active DEFAULT(1),CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCType_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDDCType UNIQUE(CompanyID,TypeCode),CONSTRAINT CK_TDDCType_Class CHECK(DocumentClass IN(N'CONTROLLED',N'GENERAL')),CONSTRAINT CK_TDDCType_Audience CHECK(DefaultAudienceMode IN(N'ALL',N'RESTRICTED')));
 IF OBJECT_ID(N'dbo.TDDCDocument',N'U') IS NULL CREATE TABLE dbo.TDDCDocument(
  DocumentID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,DocumentTypeID bigint NOT NULL,DocumentNo nvarchar(80) NOT NULL,DocumentTitle nvarchar(500) NOT NULL,DocumentClass nvarchar(20) NOT NULL,
  OwnerDepartmentID bigint NULL,OwnerUserID bigint NOT NULL,StatusCode nvarchar(30) NOT NULL,CurrentRevisionID bigint NULL,AudienceMode nvarchar(20) NOT NULL CONSTRAINT DF_TDDCDocument_Audience DEFAULT(N'ALL'),
  RequireAcknowledgement bit NOT NULL CONSTRAINT DF_TDDCDocument_Ack DEFAULT(0),PublishDate datetime2 NULL,ExpireDate datetime2 NULL,IsActive bit NOT NULL CONSTRAINT DF_TDDCDocument_Active DEFAULT(1),
  CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCDocument_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT FK_TDDCDocument_Type FOREIGN KEY(DocumentTypeID) REFERENCES dbo.TDDCDocumentType(DocumentTypeID),CONSTRAINT UQ_TDDCDocument_No UNIQUE(CompanyID,DocumentNo),
  CONSTRAINT CK_TDDCDocument_Class CHECK(DocumentClass IN(N'CONTROLLED',N'GENERAL')),CONSTRAINT CK_TDDCDocument_Status CHECK(StatusCode IN(N'DRAFT',N'IN_REVIEW',N'IN_APPROVAL',N'EFFECTIVE',N'PUBLISHED',N'OBSOLETE',N'RETURNED')),CONSTRAINT CK_TDDCDocument_Audience CHECK(AudienceMode IN(N'ALL',N'RESTRICTED')));
 IF OBJECT_ID(N'dbo.TDDCRevision',N'U') IS NULL CREATE TABLE dbo.TDDCRevision(
  RevisionID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,DocumentID bigint NOT NULL,RevisionNo nvarchar(30) NOT NULL,ChangeSummary nvarchar(2000) NULL,EffectiveDate date NULL,StatusCode nvarchar(30) NOT NULL,
  ReviewerUserID bigint NULL,ApproverUserID bigint NULL,ReviewedBy bigint NULL,ReviewedDate datetime2 NULL,ApprovedBy bigint NULL,ApprovedDate datetime2 NULL,ReturnedReason nvarchar(2000) NULL,
  CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCRevision_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT FK_TDDCRevision_Document FOREIGN KEY(DocumentID) REFERENCES dbo.TDDCDocument(DocumentID),CONSTRAINT UQ_TDDCRevision UNIQUE(CompanyID,DocumentID,RevisionNo),CONSTRAINT CK_TDDCRevision_Status CHECK(StatusCode IN(N'DRAFT',N'IN_REVIEW',N'IN_APPROVAL',N'APPROVED',N'EFFECTIVE',N'OBSOLETE',N'RETURNED')));
 IF OBJECT_ID(N'dbo.TDDCFile',N'U') IS NULL CREATE TABLE dbo.TDDCFile(
  DocumentFileID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,DocumentID bigint NOT NULL,RevisionID bigint NULL,FileRole nvarchar(20) NOT NULL,OriginalFileName nvarchar(260) NOT NULL,StoredFileName nvarchar(260) NOT NULL,RelativePath nvarchar(1000) NOT NULL,
  ContentType nvarchar(150) NOT NULL,FileSizeBytes bigint NOT NULL,Sha256 nvarchar(64) NOT NULL,CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCFile_Create DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDDCFile_Document FOREIGN KEY(DocumentID) REFERENCES dbo.TDDCDocument(DocumentID),CONSTRAINT FK_TDDCFile_Revision FOREIGN KEY(RevisionID) REFERENCES dbo.TDDCRevision(RevisionID),CONSTRAINT CK_TDDCFile_Role CHECK(FileRole IN(N'PRIMARY',N'ATTACHMENT')),CONSTRAINT CK_TDDCFile_Size CHECK(FileSizeBytes>0));
 IF OBJECT_ID(N'dbo.TDDCAccessRule',N'U') IS NULL CREATE TABLE dbo.TDDCAccessRule(
  AccessRuleID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,DocumentID bigint NOT NULL,SubjectType nvarchar(20) NOT NULL,SubjectID bigint NULL,CanView bit NOT NULL CONSTRAINT DF_TDDCAccess_View DEFAULT(1),CanPreview bit NOT NULL CONSTRAINT DF_TDDCAccess_Preview DEFAULT(1),CanDownload bit NOT NULL CONSTRAINT DF_TDDCAccess_Download DEFAULT(0),
  CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCAccess_Create DEFAULT(SYSUTCDATETIME()),CONSTRAINT FK_TDDCAccess_Document FOREIGN KEY(DocumentID) REFERENCES dbo.TDDCDocument(DocumentID) ON DELETE CASCADE,CONSTRAINT CK_TDDCAccess_Subject CHECK(SubjectType IN(N'ALL',N'DEPARTMENT',N'USER')));
 IF OBJECT_ID(N'dbo.TDDCAcknowledgement',N'U') IS NULL CREATE TABLE dbo.TDDCAcknowledgement(
  AcknowledgementID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,DocumentID bigint NOT NULL,RevisionID bigint NULL,UserID bigint NOT NULL,AcknowledgedDate datetime2 NULL,IpAddress nvarchar(80) NULL,
  CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCAck_Create DEFAULT(SYSUTCDATETIME()),CONSTRAINT FK_TDDCAck_Document FOREIGN KEY(DocumentID) REFERENCES dbo.TDDCDocument(DocumentID),CONSTRAINT FK_TDDCAck_Revision FOREIGN KEY(RevisionID) REFERENCES dbo.TDDCRevision(RevisionID),CONSTRAINT UQ_TDDCAck UNIQUE(CompanyID,DocumentID,RevisionID,UserID));
 IF OBJECT_ID(N'dbo.TDDCAudit',N'U') IS NULL CREATE TABLE dbo.TDDCAudit(
  AuditID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,DocumentID bigint NULL,RevisionID bigint NULL,ActionCode nvarchar(50) NOT NULL,DetailText nvarchar(2000) NULL,UserID bigint NOT NULL,IpAddress nvarchar(80) NULL,ActionDate datetime2 NOT NULL CONSTRAINT DF_TDDCAudit_Date DEFAULT(SYSUTCDATETIME()));
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDDCDocument') AND name=N'IX_TDDCDocument_CompanyStatus') CREATE INDEX IX_TDDCDocument_CompanyStatus ON dbo.TDDCDocument(CompanyID,DocumentClass,StatusCode,CreateDate DESC);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDDCRevision') AND name=N'IX_TDDCRevision_Assignee') CREATE INDEX IX_TDDCRevision_Assignee ON dbo.TDDCRevision(CompanyID,ReviewerUserID,ApproverUserID,StatusCode);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDDCAudit') AND name=N'IX_TDDCAudit_CompanyDate') CREATE INDEX IX_TDDCAudit_CompanyDate ON dbo.TDDCAudit(CompanyID,ActionDate DESC);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
