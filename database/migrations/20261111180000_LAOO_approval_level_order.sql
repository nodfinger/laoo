SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTCompanyApprovalLevelOrder', N'U') IS NULL
CREATE TABLE dbo.TDSTCompanyApprovalLevelOrder (
 CompanyID bigint NOT NULL CONSTRAINT PK_CompanyApprovalLevelOrder PRIMARY KEY,
 OrderMethod varchar(12) NOT NULL CONSTRAINT CK_CompanyApprovalLevelOrder_Method CHECK (OrderMethod IN ('NAME','SHORTCODE','SEQUENCE')),
 UpdateBy bigint NOT NULL,
 UpdateDate datetime2 NOT NULL CONSTRAINT DF_CompanyApprovalLevelOrder_Date DEFAULT SYSUTCDATETIME()
);
IF COL_LENGTH(N'dbo.TDSTApprovalPatternCatalog', N'LevelOrderMethod') IS NULL
 ALTER TABLE dbo.TDSTApprovalPatternCatalog ADD LevelOrderMethod varchar(12) NULL;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_ApprovalCatalog_LevelOrderMethod')
 EXEC(N'ALTER TABLE dbo.TDSTApprovalPatternCatalog ADD CONSTRAINT CK_ApprovalCatalog_LevelOrderMethod CHECK (LevelOrderMethod IS NULL OR LevelOrderMethod IN (''NAME'',''SHORTCODE'',''SEQUENCE''))');
