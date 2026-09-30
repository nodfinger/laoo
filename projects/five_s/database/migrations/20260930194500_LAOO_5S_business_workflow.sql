SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDFSSetting',N'U') IS NULL
CREATE TABLE dbo.TDFSSetting(
 CompanyID bigint NOT NULL CONSTRAINT PK_TDFSSetting PRIMARY KEY,
 IsEnabled bit NOT NULL CONSTRAINT DF_TDFSSetting_Enabled DEFAULT(1),
 ScoreMax decimal(6,2) NOT NULL CONSTRAINT DF_TDFSSetting_ScoreMax DEFAULT(5),
 DefaultPassPercent decimal(6,2) NOT NULL CONSTRAINT DF_TDFSSetting_Pass DEFAULT(80),
 RequireFailurePhoto bit NOT NULL CONSTRAINT DF_TDFSSetting_FailurePhoto DEFAULT(1),
 RequireClosurePhoto bit NOT NULL CONSTRAINT DF_TDFSSetting_ClosurePhoto DEFAULT(1),
 MaxAttachmentSizeMB decimal(6,2) NOT NULL CONSTRAINT DF_TDFSSetting_MaxMB DEFAULT(1),
 MaxAttachmentsPerItem int NOT NULL CONSTRAINT DF_TDFSSetting_MaxFiles DEFAULT(5),
 LowDueDays int NOT NULL CONSTRAINT DF_TDFSSetting_LowDays DEFAULT(14),
 MediumDueDays int NOT NULL CONSTRAINT DF_TDFSSetting_MediumDays DEFAULT(7),
 HighDueDays int NOT NULL CONSTRAINT DF_TDFSSetting_HighDays DEFAULT(3),
 AllowSelfApprove bit NOT NULL CONSTRAINT DF_TDFSSetting_SelfApprove DEFAULT(0),
 DefaultApproverUserID bigint NULL,UpdateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSSetting_Update DEFAULT SYSUTCDATETIME(),UpdateBy bigint NOT NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT CK_TDFSSetting_Score CHECK(ScoreMax>0 AND ScoreMax<=100),CONSTRAINT CK_TDFSSetting_Pass CHECK(DefaultPassPercent BETWEEN 0 AND 100),
 CONSTRAINT CK_TDFSSetting_MaxMB CHECK(MaxAttachmentSizeMB>0 AND MaxAttachmentSizeMB<=1),CONSTRAINT CK_TDFSSetting_MaxFiles CHECK(MaxAttachmentsPerItem BETWEEN 1 AND 20),
 CONSTRAINT CK_TDFSSetting_Due CHECK(LowDueDays>0 AND MediumDueDays>0 AND HighDueDays>0));

IF OBJECT_ID(N'dbo.TDFSArea',N'U') IS NULL BEGIN
 CREATE TABLE dbo.TDFSArea(AreaID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSArea PRIMARY KEY,CompanyID bigint NOT NULL,AreaCode nvarchar(30) NOT NULL,AreaName nvarchar(200) NOT NULL,
 BranchID bigint NULL,BuildingID bigint NULL,FloorID bigint NULL,RoomID bigint NULL,DepartmentID bigint NULL,OwnerUserID bigint NULL,DescriptionText nvarchar(1000) NULL,IsActive bit NOT NULL CONSTRAINT DF_TDFSArea_Active DEFAULT(1),
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSArea_Create DEFAULT SYSUTCDATETIME(),CreateBy bigint NOT NULL,UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,CONSTRAINT UQ_TDFSArea_Code UNIQUE(CompanyID,AreaCode));
 CREATE INDEX IX_TDFSArea_Company ON dbo.TDFSArea(CompanyID,IsActive,AreaName); END;

IF OBJECT_ID(N'dbo.TDFSTemplate',N'U') IS NULL BEGIN
 CREATE TABLE dbo.TDFSTemplate(TemplateID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSTemplate PRIMARY KEY,CompanyID bigint NOT NULL,TemplateCode nvarchar(30) NOT NULL,TemplateName nvarchar(200) NOT NULL,
 VersionNo int NOT NULL CONSTRAINT DF_TDFSTemplate_Version DEFAULT(1),DescriptionText nvarchar(1000) NULL,PassPercent decimal(6,2) NOT NULL,IsActive bit NOT NULL CONSTRAINT DF_TDFSTemplate_Active DEFAULT(1),
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSTemplate_Create DEFAULT SYSUTCDATETIME(),CreateBy bigint NOT NULL,UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDFSTemplate_CodeVersion UNIQUE(CompanyID,TemplateCode,VersionNo),CONSTRAINT CK_TDFSTemplate_Pass CHECK(PassPercent BETWEEN 0 AND 100));
 CREATE INDEX IX_TDFSTemplate_Company ON dbo.TDFSTemplate(CompanyID,IsActive,TemplateName); END;

IF OBJECT_ID(N'dbo.TDFSTemplateItem',N'U') IS NULL
CREATE TABLE dbo.TDFSTemplateItem(TemplateItemID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSTemplateItem PRIMARY KEY,CompanyID bigint NOT NULL,TemplateID bigint NOT NULL,CategoryCode nvarchar(20) NOT NULL,
 SortOrder int NOT NULL,QuestionText nvarchar(1000) NOT NULL,WeightValue decimal(8,2) NOT NULL CONSTRAINT DF_TDFSTemplateItem_Weight DEFAULT(1),IsCritical bit NOT NULL CONSTRAINT DF_TDFSTemplateItem_Critical DEFAULT(0),RequireFailurePhoto bit NOT NULL CONSTRAINT DF_TDFSTemplateItem_Photo DEFAULT(1),
 CONSTRAINT FK_TDFSTemplateItem_Template FOREIGN KEY(TemplateID) REFERENCES dbo.TDFSTemplate(TemplateID) ON DELETE CASCADE,CONSTRAINT CK_TDFSTemplateItem_Category CHECK(CategoryCode IN(N'SEIRI',N'SEITON',N'SEISO',N'SEIKETSU',N'SHITSUKE')),
 CONSTRAINT CK_TDFSTemplateItem_Weight CHECK(WeightValue>0),CONSTRAINT UQ_TDFSTemplateItem_Order UNIQUE(TemplateID,SortOrder));

IF OBJECT_ID(N'dbo.TDFSTeam',N'U') IS NULL
CREATE TABLE dbo.TDFSTeam(TeamID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSTeam PRIMARY KEY,CompanyID bigint NOT NULL,TeamCode nvarchar(30) NOT NULL,TeamName nvarchar(200) NOT NULL,LeaderUserID bigint NOT NULL,
 EffectiveFrom date NULL,EffectiveTo date NULL,IsActive bit NOT NULL CONSTRAINT DF_TDFSTeam_Active DEFAULT(1),CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSTeam_Create DEFAULT SYSUTCDATETIME(),CreateBy bigint NOT NULL,
 UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,CONSTRAINT UQ_TDFSTeam_Code UNIQUE(CompanyID,TeamCode),CONSTRAINT CK_TDFSTeam_Dates CHECK(EffectiveTo IS NULL OR EffectiveFrom IS NULL OR EffectiveTo>=EffectiveFrom));

IF OBJECT_ID(N'dbo.TDFSTeamMember',N'U') IS NULL
CREATE TABLE dbo.TDFSTeamMember(TeamMemberID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSTeamMember PRIMARY KEY,CompanyID bigint NOT NULL,TeamID bigint NOT NULL,UserID bigint NOT NULL,
 CONSTRAINT FK_TDFSTeamMember_Team FOREIGN KEY(TeamID) REFERENCES dbo.TDFSTeam(TeamID) ON DELETE CASCADE,CONSTRAINT UQ_TDFSTeamMember_User UNIQUE(TeamID,UserID));

IF OBJECT_ID(N'dbo.TDFSPlan',N'U') IS NULL
CREATE TABLE dbo.TDFSPlan(PlanID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSPlan PRIMARY KEY,CompanyID bigint NOT NULL,PlanNo nvarchar(40) NOT NULL,PlanName nvarchar(200) NOT NULL,TemplateID bigint NOT NULL,TeamID bigint NOT NULL,
 ApproverUserID bigint NOT NULL,StartDate date NOT NULL,EndDate date NOT NULL,FrequencyCode nvarchar(20) NOT NULL,StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDFSPlan_Status DEFAULT(N'DRAFT'),Remark nvarchar(1000) NULL,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSPlan_Create DEFAULT SYSUTCDATETIME(),CreateBy bigint NOT NULL,UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT FK_TDFSPlan_Template FOREIGN KEY(TemplateID) REFERENCES dbo.TDFSTemplate(TemplateID),CONSTRAINT FK_TDFSPlan_Team FOREIGN KEY(TeamID) REFERENCES dbo.TDFSTeam(TeamID),CONSTRAINT UQ_TDFSPlan_No UNIQUE(CompanyID,PlanNo),
 CONSTRAINT CK_TDFSPlan_Dates CHECK(EndDate>=StartDate),CONSTRAINT CK_TDFSPlan_Frequency CHECK(FrequencyCode IN(N'ONCE',N'WEEKLY',N'MONTHLY',N'QUARTERLY')),CONSTRAINT CK_TDFSPlan_Status CHECK(StatusCode IN(N'DRAFT',N'ACTIVE',N'COMPLETED',N'CANCELLED')));

IF OBJECT_ID(N'dbo.TDFSPlanArea',N'U') IS NULL
CREATE TABLE dbo.TDFSPlanArea(PlanAreaID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSPlanArea PRIMARY KEY,CompanyID bigint NOT NULL,PlanID bigint NOT NULL,AreaID bigint NOT NULL,ScheduledAt datetime2(3) NOT NULL,
 CONSTRAINT FK_TDFSPlanArea_Plan FOREIGN KEY(PlanID) REFERENCES dbo.TDFSPlan(PlanID) ON DELETE CASCADE,CONSTRAINT FK_TDFSPlanArea_Area FOREIGN KEY(AreaID) REFERENCES dbo.TDFSArea(AreaID),CONSTRAINT UQ_TDFSPlanArea UNIQUE(PlanID,AreaID,ScheduledAt));

IF OBJECT_ID(N'dbo.TDFSInspection',N'U') IS NULL BEGIN
 CREATE TABLE dbo.TDFSInspection(InspectionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSInspection PRIMARY KEY,CompanyID bigint NOT NULL,InspectionNo nvarchar(40) NOT NULL,PlanID bigint NULL,PlanAreaID bigint NULL,
 AreaID bigint NOT NULL,TemplateID bigint NOT NULL,TeamID bigint NOT NULL,InspectorUserID bigint NOT NULL,ApproverUserID bigint NOT NULL,ScheduledAt datetime2(3) NOT NULL,StartedAt datetime2(3) NULL,SubmittedAt datetime2(3) NULL,ConfirmedAt datetime2(3) NULL,ConfirmedBy bigint NULL,
 StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDFSInspection_Status DEFAULT(N'DRAFT'),TotalScore decimal(12,4) NULL,ScorePercent decimal(8,4) NULL,PassPercentSnapshot decimal(6,2) NOT NULL,
 AreaCodeSnapshot nvarchar(30) NOT NULL,AreaNameSnapshot nvarchar(200) NOT NULL,TemplateCodeSnapshot nvarchar(30) NOT NULL,TemplateNameSnapshot nvarchar(200) NOT NULL,TemplateVersionSnapshot int NOT NULL,TeamNameSnapshot nvarchar(200) NOT NULL,ReturnReason nvarchar(1000) NULL,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSInspection_Create DEFAULT SYSUTCDATETIME(),CreateBy bigint NOT NULL,UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT FK_TDFSInspection_Plan FOREIGN KEY(PlanID) REFERENCES dbo.TDFSPlan(PlanID),CONSTRAINT FK_TDFSInspection_PlanArea FOREIGN KEY(PlanAreaID) REFERENCES dbo.TDFSPlanArea(PlanAreaID),CONSTRAINT FK_TDFSInspection_Area FOREIGN KEY(AreaID) REFERENCES dbo.TDFSArea(AreaID),
 CONSTRAINT FK_TDFSInspection_Template FOREIGN KEY(TemplateID) REFERENCES dbo.TDFSTemplate(TemplateID),CONSTRAINT FK_TDFSInspection_Team FOREIGN KEY(TeamID) REFERENCES dbo.TDFSTeam(TeamID),CONSTRAINT UQ_TDFSInspection_No UNIQUE(CompanyID,InspectionNo),
 CONSTRAINT CK_TDFSInspection_Status CHECK(StatusCode IN(N'DRAFT',N'IN_PROGRESS',N'SUBMITTED',N'RETURNED',N'CONFIRMED')));
 CREATE UNIQUE INDEX UX_TDFSInspection_PlanArea ON dbo.TDFSInspection(PlanAreaID) WHERE PlanAreaID IS NOT NULL;
 CREATE INDEX IX_TDFSInspection_CompanyStatus ON dbo.TDFSInspection(CompanyID,StatusCode,ScheduledAt); END;

IF OBJECT_ID(N'dbo.TDFSInspectionDetail',N'U') IS NULL
CREATE TABLE dbo.TDFSInspectionDetail(InspectionDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSInspectionDetail PRIMARY KEY,CompanyID bigint NOT NULL,InspectionID bigint NOT NULL,TemplateItemID bigint NULL,
 CategoryCode nvarchar(20) NOT NULL,SortOrder int NOT NULL,QuestionTextSnapshot nvarchar(1000) NOT NULL,WeightSnapshot decimal(8,2) NOT NULL,IsCriticalSnapshot bit NOT NULL,RequireFailurePhotoSnapshot bit NOT NULL,
 ScoreValue decimal(8,2) NULL,IsNotApplicable bit NOT NULL CONSTRAINT DF_TDFSInspectionDetail_NA DEFAULT(0),Remark nvarchar(1000) NULL,CreateFinding bit NOT NULL CONSTRAINT DF_TDFSInspectionDetail_Finding DEFAULT(0),
 CONSTRAINT FK_TDFSInspectionDetail_Header FOREIGN KEY(InspectionID) REFERENCES dbo.TDFSInspection(InspectionID) ON DELETE CASCADE,CONSTRAINT UQ_TDFSInspectionDetail_Order UNIQUE(InspectionID,SortOrder));

IF OBJECT_ID(N'dbo.TDFSFinding',N'U') IS NULL BEGIN
 CREATE TABLE dbo.TDFSFinding(FindingID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSFinding PRIMARY KEY,CompanyID bigint NOT NULL,FindingNo nvarchar(40) NOT NULL,InspectionID bigint NOT NULL,InspectionDetailID bigint NOT NULL,AreaID bigint NOT NULL,
 SeverityCode nvarchar(10) NOT NULL,DescriptionText nvarchar(1000) NOT NULL,AssignedUserID bigint NULL,DueDate date NOT NULL,StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDFSFinding_Status DEFAULT(N'OPEN'),CorrectionText nvarchar(2000) NULL,
 SubmittedAt datetime2(3) NULL,ClosedAt datetime2(3) NULL,ClosedBy bigint NULL,ReopenReason nvarchar(1000) NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSFinding_Create DEFAULT SYSUTCDATETIME(),CreateBy bigint NOT NULL,UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT FK_TDFSFinding_Inspection FOREIGN KEY(InspectionID) REFERENCES dbo.TDFSInspection(InspectionID),CONSTRAINT FK_TDFSFinding_Detail FOREIGN KEY(InspectionDetailID) REFERENCES dbo.TDFSInspectionDetail(InspectionDetailID),CONSTRAINT FK_TDFSFinding_Area FOREIGN KEY(AreaID) REFERENCES dbo.TDFSArea(AreaID),
 CONSTRAINT UQ_TDFSFinding_No UNIQUE(CompanyID,FindingNo),CONSTRAINT UQ_TDFSFinding_Detail UNIQUE(InspectionDetailID),CONSTRAINT CK_TDFSFinding_Severity CHECK(SeverityCode IN(N'LOW',N'MEDIUM',N'HIGH')),
 CONSTRAINT CK_TDFSFinding_Status CHECK(StatusCode IN(N'OPEN',N'ASSIGNED',N'IN_PROGRESS',N'PENDING_CONFIRM',N'CLOSED',N'REOPENED')));
 CREATE INDEX IX_TDFSFinding_CompanyStatus ON dbo.TDFSFinding(CompanyID,StatusCode,DueDate); END;

IF OBJECT_ID(N'dbo.TDFSAttachment',N'U') IS NULL
CREATE TABLE dbo.TDFSAttachment(AttachmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSAttachment PRIMARY KEY,CompanyID bigint NOT NULL,InspectionID bigint NULL,InspectionDetailID bigint NULL,FindingID bigint NULL,
 StageCode nvarchar(20) NOT NULL,OriginalFileName nvarchar(255) NOT NULL,StoredPath nvarchar(1000) NOT NULL,ContentType nvarchar(100) NOT NULL,FileSizeBytes bigint NOT NULL,Width int NULL,Height int NULL,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSAttachment_Create DEFAULT SYSUTCDATETIME(),CreateBy bigint NOT NULL,
 CONSTRAINT FK_TDFSAttachment_Inspection FOREIGN KEY(InspectionID) REFERENCES dbo.TDFSInspection(InspectionID) ON DELETE CASCADE,CONSTRAINT FK_TDFSAttachment_Detail FOREIGN KEY(InspectionDetailID) REFERENCES dbo.TDFSInspectionDetail(InspectionDetailID),
 CONSTRAINT FK_TDFSAttachment_Finding FOREIGN KEY(FindingID) REFERENCES dbo.TDFSFinding(FindingID),CONSTRAINT CK_TDFSAttachment_Stage CHECK(StageCode IN(N'INSPECTION',N'FINDING_BEFORE',N'FINDING_AFTER')),CONSTRAINT CK_TDFSAttachment_Size CHECK(FileSizeBytes>0));

IF OBJECT_ID(N'dbo.TDFSAudit',N'U') IS NULL BEGIN
 CREATE TABLE dbo.TDFSAudit(AuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDFSAudit PRIMARY KEY,CompanyID bigint NOT NULL,EntityType nvarchar(30) NOT NULL,EntityID bigint NOT NULL,ActionCode nvarchar(30) NOT NULL,
 FromStatus nvarchar(20) NULL,ToStatus nvarchar(20) NULL,Remark nvarchar(1000) NULL,ActionDate datetime2(3) NOT NULL CONSTRAINT DF_TDFSAudit_Date DEFAULT SYSUTCDATETIME(),ActionBy bigint NOT NULL);
 CREATE INDEX IX_TDFSAudit_Entity ON dbo.TDFSAudit(CompanyID,EntityType,EntityID,ActionDate); END;

COMMIT TRANSACTION; END TRY
BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK TRANSACTION; THROW; END CATCH;
GO
