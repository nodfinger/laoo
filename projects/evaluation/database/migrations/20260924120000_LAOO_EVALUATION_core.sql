SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDEVTemplate',N'U') IS NULL
CREATE TABLE dbo.TDEVTemplate(
 EvaluationTemplateID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVTemplate PRIMARY KEY,
 CompanyID bigint NOT NULL, TemplateCode nvarchar(30) NOT NULL, TemplateName nvarchar(200) NOT NULL,
 SourceType nvarchar(30) NOT NULL, IsActive bit NOT NULL CONSTRAINT DF_TDEVTemplate_Active DEFAULT(1),
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDEVTemplate_Create DEFAULT(SYSUTCDATETIME()), CreateBy bigint NULL,
 UpdateDate datetime2(3) NULL, UpdateBy bigint NULL, RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDEVTemplate_Company_Code UNIQUE(CompanyID,TemplateCode),
 CONSTRAINT CK_TDEVTemplate_Source CHECK(SourceType IN(N'TRAINING_COURSE',N'TRAINING_INSTRUCTOR',N'MEETING_ROOM',N'VENDOR',N'SERVICE',N'GENERAL')));

IF OBJECT_ID(N'dbo.TDEVTemplateQuestion',N'U') IS NULL
CREATE TABLE dbo.TDEVTemplateQuestion(
 EvaluationTemplateQuestionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVTemplateQuestion PRIMARY KEY,
 EvaluationTemplateID bigint NOT NULL, CompanyID bigint NOT NULL, QuestionText nvarchar(2000) NOT NULL,
 QuestionType nvarchar(30) NOT NULL, IsRequired bit NOT NULL CONSTRAINT DF_TDEVQuestion_Required DEFAULT(1), SortOrder int NOT NULL,
 CONSTRAINT FK_TDEVQuestion_Template FOREIGN KEY(EvaluationTemplateID) REFERENCES dbo.TDEVTemplate(EvaluationTemplateID) ON DELETE CASCADE,
 CONSTRAINT CK_TDEVQuestion_Type CHECK(QuestionType IN(N'RATING_5',N'SINGLE_CHOICE',N'MULTIPLE_CHOICE',N'TEXT')),
 CONSTRAINT UQ_TDEVQuestion_Sort UNIQUE(EvaluationTemplateID,SortOrder));

IF OBJECT_ID(N'dbo.TDEVTemplateQuestionOption',N'U') IS NULL
CREATE TABLE dbo.TDEVTemplateQuestionOption(
 EvaluationTemplateQuestionOptionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVQuestionOption PRIMARY KEY,
 EvaluationTemplateQuestionID bigint NOT NULL, OptionText nvarchar(500) NOT NULL, SortOrder int NOT NULL,
 CONSTRAINT FK_TDEVOption_Question FOREIGN KEY(EvaluationTemplateQuestionID) REFERENCES dbo.TDEVTemplateQuestion(EvaluationTemplateQuestionID) ON DELETE CASCADE,
 CONSTRAINT UQ_TDEVOption_Sort UNIQUE(EvaluationTemplateQuestionID,SortOrder));

IF OBJECT_ID(N'dbo.TDEVRound',N'U') IS NULL
CREATE TABLE dbo.TDEVRound(
 EvaluationRoundID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVRound PRIMARY KEY,
 CompanyID bigint NOT NULL, RoundNo nvarchar(30) NOT NULL, RoundName nvarchar(200) NOT NULL,
 SourceType nvarchar(30) NOT NULL, SourceProjectCode nvarchar(30) NULL, ReferenceEntityID bigint NULL, ReferenceTitleSnapshot nvarchar(500) NULL,
 EvaluationTemplateID bigint NOT NULL, TemplateSnapshotJson nvarchar(max) NOT NULL, StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDEVRound_Status DEFAULT(N'DRAFT'),
 OpenDateTime datetime2(3) NULL, CloseDateTime datetime2(3) NULL, CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDEVRound_Create DEFAULT(SYSUTCDATETIME()), CreateBy bigint NULL,
 SubmitDate datetime2(3) NULL, SubmitBy bigint NULL, ApproveDate datetime2(3) NULL, ApproveBy bigint NULL, PublishDate datetime2(3) NULL, PublishBy bigint NULL, CloseBy bigint NULL,
 RowVersion rowversion NOT NULL, CONSTRAINT UQ_TDEVRound_Company_No UNIQUE(CompanyID,RoundNo),
 CONSTRAINT FK_TDEVRound_Template FOREIGN KEY(EvaluationTemplateID) REFERENCES dbo.TDEVTemplate(EvaluationTemplateID),
 CONSTRAINT CK_TDEVRound_Status CHECK(StatusCode IN(N'DRAFT',N'PENDING_APPROVAL',N'PUBLISHED',N'CLOSED',N'CANCELLED')),
 CONSTRAINT CK_TDEVRound_Dates CHECK(CloseDateTime IS NULL OR OpenDateTime IS NULL OR CloseDateTime>OpenDateTime));

IF OBJECT_ID(N'dbo.TDEVRoundTargetReference',N'U') IS NULL
CREATE TABLE dbo.TDEVRoundTargetReference(
 EvaluationRoundTargetReferenceID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVRoundTargetReference PRIMARY KEY,
 CompanyID bigint NOT NULL, EvaluationRoundID bigint NOT NULL, TargetType nvarchar(30) NOT NULL, TargetEntityID bigint NULL, TargetNameSnapshot nvarchar(500) NOT NULL,
 CONSTRAINT FK_TDEVTarget_Round FOREIGN KEY(EvaluationRoundID) REFERENCES dbo.TDEVRound(EvaluationRoundID) ON DELETE CASCADE);

IF OBJECT_ID(N'dbo.TDEVRoundRespondent',N'U') IS NULL
CREATE TABLE dbo.TDEVRoundRespondent(
 EvaluationRoundRespondentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVRoundRespondent PRIMARY KEY,
 CompanyID bigint NOT NULL, EvaluationRoundID bigint NOT NULL, UserID bigint NOT NULL, EmployeeID bigint NULL, AssignmentStatus nvarchar(20) NOT NULL CONSTRAINT DF_TDEVRespondent_Status DEFAULT(N'OPEN'),
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDEVRespondent_Create DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT FK_TDEVRespondent_Round FOREIGN KEY(EvaluationRoundID) REFERENCES dbo.TDEVRound(EvaluationRoundID) ON DELETE CASCADE,
 CONSTRAINT UQ_TDEVRespondent_Round_User UNIQUE(EvaluationRoundID,UserID), CONSTRAINT CK_TDEVRespondent_Status CHECK(AssignmentStatus IN(N'OPEN',N'SUBMITTED',N'CLOSED')));

IF OBJECT_ID(N'dbo.TDEVRoundSubmission',N'U') IS NULL
CREATE TABLE dbo.TDEVRoundSubmission(
 EvaluationRoundSubmissionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVRoundSubmission PRIMARY KEY,
 CompanyID bigint NOT NULL, EvaluationRoundID bigint NOT NULL, EvaluationRoundRespondentID bigint NOT NULL, SubmittedAt datetime2(3) NOT NULL CONSTRAINT DF_TDEVSubmission_Date DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT FK_TDEVSubmission_Round FOREIGN KEY(EvaluationRoundID) REFERENCES dbo.TDEVRound(EvaluationRoundID),
 CONSTRAINT FK_TDEVSubmission_Respondent FOREIGN KEY(EvaluationRoundRespondentID) REFERENCES dbo.TDEVRoundRespondent(EvaluationRoundRespondentID) ON DELETE CASCADE,
 CONSTRAINT UQ_TDEVSubmission_Respondent UNIQUE(EvaluationRoundRespondentID));

IF OBJECT_ID(N'dbo.TDEVRoundAnswer',N'U') IS NULL
CREATE TABLE dbo.TDEVRoundAnswer(
 EvaluationRoundAnswerID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVRoundAnswer PRIMARY KEY,
 CompanyID bigint NOT NULL, EvaluationRoundSubmissionID bigint NOT NULL, QuestionSnapshotID nvarchar(50) NOT NULL,
 RatingValue tinyint NULL, AnswerText nvarchar(4000) NULL, SelectedOptionJson nvarchar(max) NULL,
 CONSTRAINT FK_TDEVAnswer_Submission FOREIGN KEY(EvaluationRoundSubmissionID) REFERENCES dbo.TDEVRoundSubmission(EvaluationRoundSubmissionID) ON DELETE CASCADE,
 CONSTRAINT CK_TDEVAnswer_Rating CHECK(RatingValue IS NULL OR RatingValue BETWEEN 1 AND 5),
 CONSTRAINT UQ_TDEVAnswer_Submission_Question UNIQUE(EvaluationRoundSubmissionID,QuestionSnapshotID));

CREATE INDEX IX_TDEVRound_Company_Source_Status ON dbo.TDEVRound(CompanyID,SourceType,StatusCode,OpenDateTime DESC);
CREATE INDEX IX_TDEVRespondent_User_Open ON dbo.TDEVRoundRespondent(CompanyID,UserID,AssignmentStatus);
COMMIT;
