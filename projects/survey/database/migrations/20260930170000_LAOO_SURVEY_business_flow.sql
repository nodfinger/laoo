SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSurvey',N'IsEnabled') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSurvey ADD IsEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSurvey_IsEnabled DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSurvey',N'DefaultDurationDays') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSurvey ADD DefaultDurationDays int NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSurvey_Duration DEFAULT(14);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSurvey',N'RequireApproval') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSurvey ADD RequireApproval bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSurvey_Approval DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSurvey',N'DefaultAnonymous') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSurvey ADD DefaultAnonymous bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSurvey_Anonymous DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSurvey',N'ResultsAfterClose') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSurvey ADD ResultsAfterClose bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSurvey_Results DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSurvey',N'DefaultApproverEmployeeID') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSurvey ADD DefaultApproverEmployeeID bigint NULL;

IF OBJECT_ID(N'dbo.TDSVSurvey',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurvey(
  SurveyID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurvey PRIMARY KEY,
  CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,SurveyCode nvarchar(40) NOT NULL,SurveyName nvarchar(250) NOT NULL,DescriptionText nvarchar(2000) NULL,
  OpenAt datetime2 NOT NULL,CloseAt datetime2 NOT NULL,IsAnonymous bit NOT NULL CONSTRAINT DF_TDSVSurvey_Anonymous DEFAULT(1),ShowResultAfterClose bit NOT NULL CONSTRAINT DF_TDSVSurvey_ShowResult DEFAULT(1),
  ApproverEmployeeID bigint NULL,StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDSVSurvey_Status DEFAULT(N'DRAFT'),SubmittedAt datetime2 NULL,ApprovedAt datetime2 NULL,PublishedAt datetime2 NULL,ClosedAt datetime2 NULL,
  ReturnReason nvarchar(1000) NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSVSurvey_Active DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSVSurvey_CreateDate DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSVSurvey_Code UNIQUE(CompanyID,SurveyCode),CONSTRAINT CK_TDSVSurvey_Date CHECK(OpenAt<CloseAt),
  CONSTRAINT CK_TDSVSurvey_Status CHECK(StatusCode IN(N'DRAFT',N'PENDING_APPROVAL',N'RETURNED',N'APPROVED',N'PUBLISHED',N'CLOSED',N'CANCELLED'))
 );
 CREATE INDEX IX_TDSVSurvey_CompanyStatus ON dbo.TDSVSurvey(CompanyID,StatusCode,OpenAt,CloseAt);
END;

IF OBJECT_ID(N'dbo.TDSVSurveyQuestion',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyQuestion(
  QuestionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyQuestion PRIMARY KEY,CompanyID bigint NOT NULL,SurveyID bigint NOT NULL,QuestionNo int NOT NULL,
  QuestionText nvarchar(1000) NOT NULL,QuestionType nvarchar(20) NOT NULL,IsRequired bit NOT NULL CONSTRAINT DF_TDSVSurveyQuestion_Required DEFAULT(1),MinValue int NULL,MaxValue int NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSVSurveyQuestion_Active DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyQuestion_CreateDate DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT FK_TDSVSurveyQuestion_Survey FOREIGN KEY(SurveyID) REFERENCES dbo.TDSVSurvey(SurveyID),CONSTRAINT UQ_TDSVSurveyQuestion_No UNIQUE(SurveyID,QuestionNo),
  CONSTRAINT CK_TDSVSurveyQuestion_Type CHECK(QuestionType IN(N'SINGLE',N'MULTI',N'SCALE',N'TEXT',N'YES_NO'))
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyQuestionOption',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyQuestionOption(
  OptionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyQuestionOption PRIMARY KEY,CompanyID bigint NOT NULL,QuestionID bigint NOT NULL,OptionNo int NOT NULL,OptionText nvarchar(500) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSVSurveyQuestionOption_Active DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyQuestionOption_CreateDate DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDSVSurveyQuestionOption_Question FOREIGN KEY(QuestionID) REFERENCES dbo.TDSVSurveyQuestion(QuestionID),CONSTRAINT UQ_TDSVSurveyQuestionOption_No UNIQUE(QuestionID,OptionNo)
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyTargetDepartment',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyTargetDepartment(
  SurveyTargetDepartmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyTargetDepartment PRIMARY KEY,CompanyID bigint NOT NULL,SurveyID bigint NOT NULL,DepartmentOrgUnitID bigint NOT NULL,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyTargetDepartment_CreateDate DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDSVSurveyTargetDepartment_Survey FOREIGN KEY(SurveyID) REFERENCES dbo.TDSVSurvey(SurveyID),CONSTRAINT UQ_TDSVSurveyTargetDepartment UNIQUE(SurveyID,DepartmentOrgUnitID)
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyTargetEmployee',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyTargetEmployee(
  SurveyTargetEmployeeID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyTargetEmployee PRIMARY KEY,CompanyID bigint NOT NULL,SurveyID bigint NOT NULL,EmployeeID bigint NOT NULL,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyTargetEmployee_CreateDate DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDSVSurveyTargetEmployee_Survey FOREIGN KEY(SurveyID) REFERENCES dbo.TDSVSurvey(SurveyID),CONSTRAINT UQ_TDSVSurveyTargetEmployee UNIQUE(SurveyID,EmployeeID)
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyAssignment',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyAssignment(
  AssignmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyAssignment PRIMARY KEY,CompanyID bigint NOT NULL,SurveyID bigint NOT NULL,EmployeeID bigint NOT NULL,
  AssignedAt datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyAssignment_AssignedAt DEFAULT(SYSUTCDATETIME()),ReminderCount int NOT NULL CONSTRAINT DF_TDSVSurveyAssignment_Reminder DEFAULT(0),LastReminderAt datetime2 NULL,
  RespondedAt datetime2 NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSVSurveyAssignment_Active DEFAULT(1),CreateBy bigint NULL,
  CONSTRAINT FK_TDSVSurveyAssignment_Survey FOREIGN KEY(SurveyID) REFERENCES dbo.TDSVSurvey(SurveyID),CONSTRAINT UQ_TDSVSurveyAssignment UNIQUE(SurveyID,EmployeeID)
 );
 CREATE INDEX IX_TDSVSurveyAssignment_Employee ON dbo.TDSVSurveyAssignment(CompanyID,EmployeeID,IsActive);
END;

IF OBJECT_ID(N'dbo.TDSVSurveyApprovalHistory',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyApprovalHistory(
  ApprovalHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyApprovalHistory PRIMARY KEY,CompanyID bigint NOT NULL,SurveyID bigint NOT NULL,ActionCode nvarchar(30) NOT NULL,
  ActionByEmployeeID bigint NULL,ReasonText nvarchar(1000) NULL,ActionAt datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyApprovalHistory_ActionAt DEFAULT(SYSUTCDATETIME()),CreateBy bigint NULL,
  CONSTRAINT FK_TDSVSurveyApprovalHistory_Survey FOREIGN KEY(SurveyID) REFERENCES dbo.TDSVSurvey(SurveyID)
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyResponse',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyResponse(
  ResponseID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyResponse PRIMARY KEY,CompanyID bigint NOT NULL,SurveyID bigint NOT NULL,AssignmentID bigint NOT NULL,
  StartedAt datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyResponse_StartedAt DEFAULT(SYSUTCDATETIME()),SubmittedAt datetime2 NOT NULL,CreateBy bigint NULL,
  CONSTRAINT FK_TDSVSurveyResponse_Survey FOREIGN KEY(SurveyID) REFERENCES dbo.TDSVSurvey(SurveyID),CONSTRAINT FK_TDSVSurveyResponse_Assignment FOREIGN KEY(AssignmentID) REFERENCES dbo.TDSVSurveyAssignment(AssignmentID),CONSTRAINT UQ_TDSVSurveyResponse_Assignment UNIQUE(AssignmentID)
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyAnswer',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyAnswer(
  AnswerID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyAnswer PRIMARY KEY,CompanyID bigint NOT NULL,ResponseID bigint NOT NULL,QuestionID bigint NOT NULL,TextValue nvarchar(max) NULL,NumberValue decimal(18,4) NULL,
  CONSTRAINT FK_TDSVSurveyAnswer_Response FOREIGN KEY(ResponseID) REFERENCES dbo.TDSVSurveyResponse(ResponseID),CONSTRAINT FK_TDSVSurveyAnswer_Question FOREIGN KEY(QuestionID) REFERENCES dbo.TDSVSurveyQuestion(QuestionID),CONSTRAINT UQ_TDSVSurveyAnswer_Question UNIQUE(ResponseID,QuestionID)
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyAnswerOption',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyAnswerOption(
  AnswerOptionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyAnswerOption PRIMARY KEY,CompanyID bigint NOT NULL,AnswerID bigint NOT NULL,OptionID bigint NOT NULL,
  CONSTRAINT FK_TDSVSurveyAnswerOption_Answer FOREIGN KEY(AnswerID) REFERENCES dbo.TDSVSurveyAnswer(AnswerID),CONSTRAINT FK_TDSVSurveyAnswerOption_Option FOREIGN KEY(OptionID) REFERENCES dbo.TDSVSurveyQuestionOption(OptionID),CONSTRAINT UQ_TDSVSurveyAnswerOption UNIQUE(AnswerID,OptionID)
 );
END;

IF OBJECT_ID(N'dbo.TDSVSurveyDeliveryHistory',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSVSurveyDeliveryHistory(
  DeliveryHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSVSurveyDeliveryHistory PRIMARY KEY,CompanyID bigint NOT NULL,SurveyID bigint NOT NULL,ActionCode nvarchar(30) NOT NULL,RecipientCount int NOT NULL,
  ActionAt datetime2 NOT NULL CONSTRAINT DF_TDSVSurveyDeliveryHistory_ActionAt DEFAULT(SYSUTCDATETIME()),CreateBy bigint NULL,
  CONSTRAINT FK_TDSVSurveyDeliveryHistory_Survey FOREIGN KEY(SurveyID) REFERENCES dbo.TDSVSurvey(SurveyID)
 );
END;

DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SURVEY' AND IsActive=1);
IF @ProjectID IS NULL THROW 56400,N'LAOO_SURVEY project is missing.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@ProjectID AND ScreenCode=N'40004' AND ActionCode=N'EDIT')
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
 SELECT @ProjectID,N'40004',MenuName,N'Survey delivery',N'EDIT',N'แก้ไข',N'Edit',1,SYSUTCDATETIME() FROM dbo.TDADMainMenu WHERE MenuCode=N'40004';
ELSE UPDATE dbo.TDADPermission SET IsActive=1,ModifiedDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND ScreenCode=N'40004' AND ActionCode=N'EDIT';
UPDATE PM SET IsActive=1 FROM dbo.TDADProjectMenu PM WHERE PM.ProjectID=@ProjectID AND PM.MenuCode BETWEEN N'40001' AND N'40007';
