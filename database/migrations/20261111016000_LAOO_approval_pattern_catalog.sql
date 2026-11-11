SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTApprovalPatternCatalog', N'U') IS NULL
CREATE TABLE dbo.TDSTApprovalPatternCatalog (
    CompanyID bigint NOT NULL,
    PatternCode nvarchar(50) NOT NULL,
    PatternName nvarchar(200) NOT NULL,
    PatternType varchar(16) NOT NULL CONSTRAINT DF_ApprovalPatternCatalog_Type DEFAULT 'MANUAL',
    LevelsUp int NULL,
    UpdateBy bigint NOT NULL,
    UpdateDate datetime2 NOT NULL CONSTRAINT DF_ApprovalPatternCatalog_UpdateDate DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ApprovalPatternCatalog PRIMARY KEY (CompanyID, PatternCode),
    CONSTRAINT CK_ApprovalPatternCatalog_Type CHECK (PatternType IN ('MANUAL','LEVEL','POSITION')),
    CONSTRAINT CK_ApprovalPatternCatalog_Levels CHECK ((PatternType='LEVEL' AND LevelsUp>0) OR (PatternType<>'LEVEL' AND LevelsUp IS NULL))
);

IF OBJECT_ID(N'dbo.TDSTApprovalPatternCatalogStep', N'U') IS NULL
CREATE TABLE dbo.TDSTApprovalPatternCatalogStep (
    CompanyID bigint NOT NULL,
    PatternCode nvarchar(50) NOT NULL,
    StepNo int NOT NULL,
    ApprovalCondition varchar(3) NOT NULL,
    CONSTRAINT PK_ApprovalPatternCatalogStep PRIMARY KEY (CompanyID, PatternCode, StepNo),
    CONSTRAINT FK_ApprovalPatternCatalogStep_Catalog FOREIGN KEY (CompanyID, PatternCode) REFERENCES dbo.TDSTApprovalPatternCatalog(CompanyID, PatternCode) ON DELETE CASCADE,
    CONSTRAINT CK_ApprovalPatternCatalogStep_Number CHECK (StepNo>0),
    CONSTRAINT CK_ApprovalPatternCatalogStep_Condition CHECK (ApprovalCondition IN ('ANY','ALL'))
);

IF OBJECT_ID(N'dbo.TDSTApprovalPatternCatalogPosition', N'U') IS NULL
CREATE TABLE dbo.TDSTApprovalPatternCatalogPosition (
    CompanyID bigint NOT NULL,
    PatternCode nvarchar(50) NOT NULL,
    StepNo int NOT NULL,
    PositionCode nvarchar(20) NOT NULL,
    UnitScope varchar(12) NOT NULL,
    CONSTRAINT PK_ApprovalPatternCatalogPosition PRIMARY KEY (CompanyID, PatternCode, StepNo, PositionCode),
    CONSTRAINT UQ_ApprovalPatternCatalogPosition UNIQUE (CompanyID, PatternCode, PositionCode),
    CONSTRAINT FK_ApprovalPatternCatalogPosition_Step FOREIGN KEY (CompanyID, PatternCode, StepNo) REFERENCES dbo.TDSTApprovalPatternCatalogStep(CompanyID, PatternCode, StepNo) ON DELETE CASCADE,
    CONSTRAINT CK_ApprovalPatternCatalogPosition_Scope CHECK (UnitScope IN ('ANY','DEPARTMENT','DIVISION'))
);

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10011' AND RouteName=N'companyApprovalPattern')
    THROW 51000, 'Approval pattern menu was not found.', 1;
UPDATE dbo.TDADMainMenu SET ScreenType=1 WHERE MenuCode=N'10011' AND RouteName=N'companyApprovalPattern';
