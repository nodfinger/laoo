SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADAiCapabilityCompany', N'U') IS NULL
    THROW 54020, N'AI capability company table is missing.', 1;

IF COL_LENGTH(N'dbo.TDADAiCapabilityCompany', N'LastApprovedByUsername') IS NULL
    ALTER TABLE dbo.TDADAiCapabilityCompany ADD LastApprovedByUsername nvarchar(256) NULL;

IF COL_LENGTH(N'dbo.TDADAiCapabilityCompany', N'LastApprovedAt') IS NULL
    ALTER TABLE dbo.TDADAiCapabilityCompany ADD LastApprovedAt datetime2 NULL;
