SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTCompanyApprovalPattern',N'U') IS NULL
CREATE TABLE dbo.TDSTCompanyApprovalPattern (
    CompanyID bigint NOT NULL CONSTRAINT PK_CompanyApprovalPattern PRIMARY KEY,
    LevelsUp int NOT NULL,
    UpdateBy bigint NOT NULL,
    UpdateDate datetime2 NOT NULL CONSTRAINT DF_CompanyApprovalPattern_UpdateDate DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_CompanyApprovalPattern_LevelsUp CHECK(LevelsUp>0)
);

IF OBJECT_ID(N'dbo.TDSTCompanyApprovalStep',N'U') IS NULL
CREATE TABLE dbo.TDSTCompanyApprovalStep (
    CompanyID bigint NOT NULL,
    StepNo int NOT NULL,
    ApprovalCondition varchar(3) NOT NULL,
    CONSTRAINT PK_CompanyApprovalStep PRIMARY KEY(CompanyID,StepNo),
    CONSTRAINT FK_CompanyApprovalStep_Pattern FOREIGN KEY(CompanyID)
        REFERENCES dbo.TDSTCompanyApprovalPattern(CompanyID) ON DELETE CASCADE,
    CONSTRAINT CK_CompanyApprovalStep_Number CHECK(StepNo>0),
    CONSTRAINT CK_CompanyApprovalStep_Condition CHECK(ApprovalCondition IN ('ANY','ALL'))
);

IF OBJECT_ID(N'dbo.TDSTCompanyApprovalPosition',N'U') IS NULL
CREATE TABLE dbo.TDSTCompanyApprovalPosition (
    CompanyID bigint NOT NULL,
    StepNo int NOT NULL,
    PositionCode nvarchar(20) NOT NULL,
    UnitScope varchar(12) NOT NULL CONSTRAINT DF_CompanyApprovalPosition_UnitScope DEFAULT 'ANY',
    CONSTRAINT PK_CompanyApprovalPosition PRIMARY KEY(CompanyID,StepNo,PositionCode),
    CONSTRAINT UQ_CompanyApprovalPosition_CompanyPosition UNIQUE(CompanyID,PositionCode),
    CONSTRAINT CK_CompanyApprovalPosition_UnitScope CHECK(UnitScope IN ('ANY','DEPARTMENT','DIVISION')),
    CONSTRAINT FK_CompanyApprovalPosition_Step FOREIGN KEY(CompanyID,StepNo)
        REFERENCES dbo.TDSTCompanyApprovalStep(CompanyID,StepNo) ON DELETE CASCADE
);
