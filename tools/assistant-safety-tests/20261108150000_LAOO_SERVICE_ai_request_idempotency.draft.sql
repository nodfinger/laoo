SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADServiceRequest', N'U') IS NULL
    THROW 53800, N'Service request table is missing.', 1;
IF COL_LENGTH(N'dbo.TDADServiceRequest', N'AiRequestKey') IS NOT NULL
    THROW 53801, N'AiRequestKey already exists; migration stopped.', 1;

ALTER TABLE dbo.TDADServiceRequest ADD AiRequestKey uniqueidentifier NULL;
CREATE UNIQUE INDEX UX_ServiceRequest_AiRequestKey
    ON dbo.TDADServiceRequest(CompanyID, CreateBy, AiRequestKey)
    WHERE AiRequestKey IS NOT NULL;
