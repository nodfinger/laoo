IF COL_LENGTH(N'dbo.TDADServiceRequest',N'AssignedEmployeeID') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD AssignedEmployeeID bigint NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'AssignedEmployeeNameSnapshot') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD AssignedEmployeeNameSnapshot nvarchar(200) NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'ReceivedDate') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD ReceivedDate datetime2(3) NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'ReceivedBy') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD ReceivedBy bigint NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'StartedDate') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD StartedDate datetime2(3) NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'StartedBy') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD StartedBy bigint NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'CompletedDate') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD CompletedDate datetime2(3) NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'CompletedBy') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD CompletedBy bigint NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'ResolutionDetail') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD ResolutionDetail nvarchar(2000) NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'CancellationReason') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD CancellationReason nvarchar(1000) NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceRequest') AND name=N'IX_TDADServiceRequest_AssignedEmployee')
    CREATE INDEX IX_TDADServiceRequest_AssignedEmployee ON dbo.TDADServiceRequest(CompanyID,AssignedEmployeeID,StatusCode);
