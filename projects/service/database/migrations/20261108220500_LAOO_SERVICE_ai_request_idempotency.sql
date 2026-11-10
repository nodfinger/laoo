SET NOCOUNT ON;
SET XACT_ABORT ON;
IF COL_LENGTH(N'dbo.TDADServiceRequest', N'AiRequestKey') IS NULL
    ALTER TABLE dbo.TDADServiceRequest ADD AiRequestKey uniqueidentifier NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceRequest') AND name=N'UX_TDADServiceRequest_AiRequestKey')
    EXEC(N'CREATE UNIQUE INDEX UX_TDADServiceRequest_AiRequestKey ON dbo.TDADServiceRequest(CompanyID,CreateBy,AiRequestKey) WHERE AiRequestKey IS NOT NULL;');
