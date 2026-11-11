SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTApprovalPatternCatalog',N'U') IS NULL
 THROW 54221,N'Approval pattern catalog is not installed.',1;
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDSTApprovalPatternCatalog') AND name=N'CK_ApprovalPatternCatalog_Type')
 ALTER TABLE dbo.TDSTApprovalPatternCatalog DROP CONSTRAINT CK_ApprovalPatternCatalog_Type;
ALTER TABLE dbo.TDSTApprovalPatternCatalog WITH CHECK ADD CONSTRAINT CK_ApprovalPatternCatalog_Type CHECK (PatternType IN ('MANUAL','LEVEL','POSITION','SPECIFIC'));
