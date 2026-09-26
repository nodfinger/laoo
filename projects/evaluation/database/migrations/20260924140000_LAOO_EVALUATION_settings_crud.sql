SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.TDEVSystemSetting',N'U') IS NULL
CREATE TABLE dbo.TDEVSystemSetting(
 EvaluationSystemSettingID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEVSystemSetting PRIMARY KEY,
 CompanyID bigint NOT NULL,SourceType nvarchar(30) NOT NULL,DefaultEvaluationTemplateID bigint NULL,
 IsActive bit NOT NULL CONSTRAINT DF_TDEVSystemSetting_Active DEFAULT(1),CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDEVSystemSetting_Create DEFAULT(SYSUTCDATETIME()),CreateBy bigint NULL,UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,
 CONSTRAINT UQ_TDEVSystemSetting_Company_Source UNIQUE(CompanyID,SourceType),
 CONSTRAINT FK_TDEVSystemSetting_Template FOREIGN KEY(DefaultEvaluationTemplateID) REFERENCES dbo.TDEVTemplate(EvaluationTemplateID),
 CONSTRAINT CK_TDEVSystemSetting_Source CHECK(SourceType IN(N'TRAINING_COURSE',N'TRAINING_INSTRUCTOR',N'MEETING_ROOM',N'VENDOR',N'SERVICE',N'GENERAL')));
UPDATE dbo.TDADMainMenu SET ScreenType=1,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'47001';
COMMIT TRANSACTION;
