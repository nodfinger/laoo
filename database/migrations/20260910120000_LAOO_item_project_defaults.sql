-- Run through Laoo.MigrationRunner: transaction, application lock and checksum ledger.
-- No existing item, usage, stock or document is rewritten.
SET XACT_ABORT ON;
CREATE TABLE dbo.TDIVItemProjectPolicy (
 CompanyID bigint NOT NULL,
 ItemID bigint NOT NULL,
 AccessModeCode nvarchar(20) NOT NULL,
 UpdateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 UpdatedBy bigint NOT NULL,
 CONSTRAINT PK_TDIVItemProjectPolicy PRIMARY KEY(CompanyID,ItemID),
 CONSTRAINT FK_TDIVItemProjectPolicy_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID) ON DELETE CASCADE,
 CONSTRAINT CK_TDIVItemProjectPolicy_Mode CHECK(AccessModeCode IN ('ALL','SELECTED'))
);
CREATE TABLE dbo.TDIVItemProject (
 CompanyID bigint NOT NULL,
 ItemID bigint NOT NULL,
 ProjectID bigint NOT NULL,
 CONSTRAINT PK_TDIVItemProject PRIMARY KEY(CompanyID,ItemID,ProjectID),
 CONSTRAINT FK_TDIVItemProject_Policy FOREIGN KEY(CompanyID,ItemID) REFERENCES dbo.TDIVItemProjectPolicy(CompanyID,ItemID) ON DELETE CASCADE,
 CONSTRAINT FK_TDIVItemProject_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID)
);
CREATE TABLE dbo.TDIVItemClassificationDefault (
 CompanyID bigint NOT NULL,
 ScopeCode nvarchar(10) NOT NULL,
 ClassificationCode nvarchar(50) NOT NULL,
 ItemKindCode nvarchar(20) NOT NULL,
 StockTrackingCode nvarchar(20) NOT NULL,
 UsageCodesJson nvarchar(500) NOT NULL,
 UpdateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 UpdatedBy bigint NOT NULL,
 CONSTRAINT PK_TDIVItemClassificationDefault PRIMARY KEY(CompanyID,ScopeCode,ClassificationCode),
 CONSTRAINT CK_TDIVItemClassificationDefault_Scope CHECK(ScopeCode IN ('GROUP','TYPE')),
 CONSTRAINT CK_TDIVItemClassificationDefault_Kind CHECK(ItemKindCode IN ('GOODS','SERVICE')),
 CONSTRAINT CK_TDIVItemClassificationDefault_Tracking CHECK(StockTrackingCode IN ('NONE','QUANTITY','SERIAL') AND (ItemKindCode='GOODS' OR StockTrackingCode='NONE')),
 CONSTRAINT CK_TDIVItemClassificationDefault_Usage CHECK(ISJSON(UsageCodesJson)=1)
);
