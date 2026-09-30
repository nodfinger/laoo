SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
  BEGIN TRANSACTION;

  DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES' AND IsActive=1);
  IF @ProjectID IS NULL THROW 56300,N'Active LAOO_SALES project is required.',1;

  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSales',N'IsEnabled') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSales ADD IsEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSales_IsEnabled DEFAULT(1);
  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSales',N'LeadIdleDays') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSales ADD LeadIdleDays int NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSales_LeadIdleDays DEFAULT(14);
  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSales',N'ActivityReminderDays') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSales ADD ActivityReminderDays int NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemSales_ActivityReminderDays DEFAULT(2);
  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSales',N'DefaultStageID') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSales ADD DefaultStageID bigint NULL;
  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSales',N'WonStageID') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSales ADD WonStageID bigint NULL;
  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemSales',N'LostStageID') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemSales ADD LostStageID bigint NULL;

  IF OBJECT_ID(N'dbo.TDSLPipelineStage',N'U') IS NULL CREATE TABLE dbo.TDSLPipelineStage(
    PipelineStageID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSLPipelineStage PRIMARY KEY,
    CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,StageCode nvarchar(30) NOT NULL,StageName nvarchar(150) NOT NULL,
    SortOrder int NOT NULL,ProbabilityPercent decimal(5,2) NOT NULL,StageType nvarchar(10) NOT NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSLPipelineStage_IsActive DEFAULT(1),
    CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDSLPipelineStage_CreateDate DEFAULT SYSUTCDATETIME(),UpdateBy bigint NULL,UpdateDate datetime2(3) NULL,
    CONSTRAINT UQ_TDSLPipelineStage_Company_Code UNIQUE(CompanyID,StageCode),
    CONSTRAINT CK_TDSLPipelineStage_Probability CHECK(ProbabilityPercent>=0 AND ProbabilityPercent<=100),
    CONSTRAINT CK_TDSLPipelineStage_Type CHECK(StageType IN(N'OPEN',N'WON',N'LOST'))
  );

  IF OBJECT_ID(N'dbo.TDSLLead',N'U') IS NULL CREATE TABLE dbo.TDSLLead(
    LeadID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSLLead PRIMARY KEY,
    CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,LeadCode nvarchar(30) NOT NULL,LeadType nvarchar(20) NOT NULL,
    LeadName nvarchar(200) NOT NULL,ContactName nvarchar(200) NULL,Phone nvarchar(50) NULL,Email nvarchar(320) NULL,TaxID nvarchar(50) NULL,AddressText nvarchar(1000) NULL,
    SourceCode nvarchar(50) NULL,ScoreValue int NOT NULL CONSTRAINT DF_TDSLLead_Score DEFAULT(0),StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSLLead_Status DEFAULT(N'NEW'),
    AssignedEmployeeID bigint NULL,LastContactAt datetime2(3) NULL,NextContactAt datetime2(3) NULL,ConvertedCustomerID bigint NULL,ConvertedOpportunityID bigint NULL,
    Remark nvarchar(2000) NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSLLead_IsActive DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDSLLead_CreateDate DEFAULT SYSUTCDATETIME(),UpdateBy bigint NULL,UpdateDate datetime2(3) NULL,
    CONSTRAINT UQ_TDSLLead_Company_Code UNIQUE(CompanyID,LeadCode),
    CONSTRAINT CK_TDSLLead_Type CHECK(LeadType IN(N'COMPANY',N'PERSON')),
    CONSTRAINT CK_TDSLLead_Score CHECK(ScoreValue>=0 AND ScoreValue<=100),
    CONSTRAINT CK_TDSLLead_Status CHECK(StatusCode IN(N'NEW',N'CONTACTED',N'QUALIFIED',N'CONVERTED',N'DISQUALIFIED'))
  );

  IF OBJECT_ID(N'dbo.TDSLOpportunity',N'U') IS NULL CREATE TABLE dbo.TDSLOpportunity(
    OpportunityID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSLOpportunity PRIMARY KEY,
    CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,OpportunityCode nvarchar(30) NOT NULL,OpportunityName nvarchar(200) NOT NULL,
    CustomerID bigint NOT NULL,LeadID bigint NULL,PipelineStageID bigint NOT NULL,Amount decimal(18,4) NOT NULL CONSTRAINT DF_TDSLOpportunity_Amount DEFAULT(0),ProbabilityPercent decimal(5,2) NOT NULL,
    ExpectedCloseDate date NOT NULL,AssignedEmployeeID bigint NULL,CompetitorName nvarchar(200) NULL,Remark nvarchar(2000) NULL,
    StatusCode nvarchar(10) NOT NULL CONSTRAINT DF_TDSLOpportunity_Status DEFAULT(N'OPEN'),ClosedDate date NULL,CloseReason nvarchar(1000) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_TDSLOpportunity_IsActive DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDSLOpportunity_CreateDate DEFAULT SYSUTCDATETIME(),UpdateBy bigint NULL,UpdateDate datetime2(3) NULL,
    CONSTRAINT UQ_TDSLOpportunity_Company_Code UNIQUE(CompanyID,OpportunityCode),
    CONSTRAINT FK_TDSLOpportunity_Stage FOREIGN KEY(PipelineStageID) REFERENCES dbo.TDSLPipelineStage(PipelineStageID),
    CONSTRAINT CK_TDSLOpportunity_Amount CHECK(Amount>=0),CONSTRAINT CK_TDSLOpportunity_Probability CHECK(ProbabilityPercent>=0 AND ProbabilityPercent<=100),
    CONSTRAINT CK_TDSLOpportunity_Status CHECK(StatusCode IN(N'OPEN',N'WON',N'LOST'))
  );

  IF OBJECT_ID(N'dbo.TDSLActivity',N'U') IS NULL CREATE TABLE dbo.TDSLActivity(
    ActivityID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSLActivity PRIMARY KEY,
    CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,ActivityCode nvarchar(30) NOT NULL,ActivityType nvarchar(20) NOT NULL,Title nvarchar(200) NOT NULL,
    LeadID bigint NULL,CustomerID bigint NULL,OpportunityID bigint NULL,AssignedEmployeeID bigint NOT NULL,StartAt datetime2(3) NOT NULL,DueAt datetime2(3) NOT NULL,
    CompletedAt datetime2(3) NULL,StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSLActivity_Status DEFAULT(N'PENDING'),DescriptionText nvarchar(2000) NULL,ResultText nvarchar(2000) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_TDSLActivity_IsActive DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDSLActivity_CreateDate DEFAULT SYSUTCDATETIME(),UpdateBy bigint NULL,UpdateDate datetime2(3) NULL,
    CONSTRAINT UQ_TDSLActivity_Company_Code UNIQUE(CompanyID,ActivityCode),
    CONSTRAINT FK_TDSLActivity_Lead FOREIGN KEY(LeadID) REFERENCES dbo.TDSLLead(LeadID),
    CONSTRAINT FK_TDSLActivity_Opportunity FOREIGN KEY(OpportunityID) REFERENCES dbo.TDSLOpportunity(OpportunityID),
    CONSTRAINT CK_TDSLActivity_Type CHECK(ActivityType IN(N'CALL',N'MEETING',N'EMAIL',N'TASK')),
    CONSTRAINT CK_TDSLActivity_Status CHECK(StatusCode IN(N'PENDING',N'IN_PROGRESS',N'DONE',N'CANCELLED')),
    CONSTRAINT CK_TDSLActivity_Dates CHECK(DueAt>=StartAt),
    CONSTRAINT CK_TDSLActivity_Relation CHECK(LeadID IS NOT NULL OR CustomerID IS NOT NULL OR OpportunityID IS NOT NULL)
  );

  IF OBJECT_ID(N'dbo.TDSLOpportunityQuotation',N'U') IS NULL CREATE TABLE dbo.TDSLOpportunityQuotation(
    OpportunityQuotationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSLOpportunityQuotation PRIMARY KEY,
    CompanyID bigint NOT NULL,OpportunityID bigint NOT NULL,QuotationID bigint NOT NULL,CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDSLOpportunityQuotation_CreateDate DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_TDSLOpportunityQuotation UNIQUE(CompanyID,OpportunityID,QuotationID),
    CONSTRAINT FK_TDSLOpportunityQuotation_Opportunity FOREIGN KEY(OpportunityID) REFERENCES dbo.TDSLOpportunity(OpportunityID)
  );

  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_TDSLLead_Company_Status_Owner' AND object_id=OBJECT_ID(N'dbo.TDSLLead')) CREATE INDEX IX_TDSLLead_Company_Status_Owner ON dbo.TDSLLead(CompanyID,StatusCode,AssignedEmployeeID,NextContactAt);
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_TDSLOpportunity_Company_Status_Stage' AND object_id=OBJECT_ID(N'dbo.TDSLOpportunity')) CREATE INDEX IX_TDSLOpportunity_Company_Status_Stage ON dbo.TDSLOpportunity(CompanyID,StatusCode,PipelineStageID,AssignedEmployeeID);
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_TDSLActivity_Company_Owner_Due' AND object_id=OBJECT_ID(N'dbo.TDSLActivity')) CREATE INDEX IX_TDSLActivity_Company_Owner_Due ON dbo.TDSLActivity(CompanyID,AssignedEmployeeID,StatusCode,DueAt);

  UPDATE dbo.TDADProjectMenu SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode IN(N'45001',N'45002',N'45003',N'45004',N'45005',N'45006',N'45007');

  INSERT dbo.TDSLPipelineStage(CompanyID,ProjectID,StageCode,StageName,SortOrder,ProbabilityPercent,StageType)
  SELECT s.CompanyID,@ProjectID,v.Code,v.Name,v.SortOrder,v.Probability,v.StageType
  FROM dbo.TDSTCompanySetupSystemSales s
  CROSS APPLY(VALUES(N'NEW',N'เริ่มต้น',10,10.00,N'OPEN'),(N'QUALIFIED',N'ผ่านการคัดกรอง',20,30.00,N'OPEN'),(N'PROPOSAL',N'เสนอราคา',30,60.00,N'OPEN'),(N'NEGOTIATION',N'เจรจาต่อรอง',40,80.00,N'OPEN'),(N'WON',N'ปิดการขายสำเร็จ',90,100.00,N'WON'),(N'LOST',N'ปิดการขายไม่สำเร็จ',100,0.00,N'LOST'))v(Code,Name,SortOrder,Probability,StageType)
  WHERE s.ProjectID=@ProjectID AND NOT EXISTS(SELECT 1 FROM dbo.TDSLPipelineStage p WHERE p.CompanyID=s.CompanyID AND p.StageCode=v.Code);

  EXEC sys.sp_executesql N'
    UPDATE s SET
      DefaultStageID=(SELECT TOP 1 PipelineStageID FROM dbo.TDSLPipelineStage p WHERE p.CompanyID=s.CompanyID AND p.StageType=N''OPEN'' ORDER BY SortOrder),
      WonStageID=(SELECT TOP 1 PipelineStageID FROM dbo.TDSLPipelineStage p WHERE p.CompanyID=s.CompanyID AND p.StageType=N''WON'' ORDER BY SortOrder),
      LostStageID=(SELECT TOP 1 PipelineStageID FROM dbo.TDSLPipelineStage p WHERE p.CompanyID=s.CompanyID AND p.StageType=N''LOST'' ORDER BY SortOrder)
    FROM dbo.TDSTCompanySetupSystemSales s
    WHERE s.ProjectID=@p AND (s.DefaultStageID IS NULL OR s.WonStageID IS NULL OR s.LostStageID IS NULL);',
    N'@p bigint',@p=@ProjectID;

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO
