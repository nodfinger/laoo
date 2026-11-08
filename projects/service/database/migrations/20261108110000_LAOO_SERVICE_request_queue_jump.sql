SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADServiceRequest', N'U') IS NULL
    THROW 53710, N'Service request table is missing.', 1;
IF COL_LENGTH(N'dbo.TDADServiceRequest', N'IsQueueJump') IS NOT NULL
    THROW 53711, N'IsQueueJump already exists; migration stopped.', 1;

ALTER TABLE dbo.TDADServiceRequest ADD IsQueueJump bit NOT NULL
    CONSTRAINT DF_ServiceRequest_IsQueueJump DEFAULT (0) WITH VALUES;
