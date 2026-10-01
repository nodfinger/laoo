SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemIntranet',N'IsEnabled') IS NULL
 ALTER TABLE dbo.TDSTCompanySetupSystemIntranet
 ADD IsEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_Enabled_Compat DEFAULT(1);

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemIntranet',N'RequireApproval') IS NULL
 ALTER TABLE dbo.TDSTCompanySetupSystemIntranet
 ADD RequireApproval bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_Approval_Compat DEFAULT(1);

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemIntranet',N'AllowSelfApproval') IS NULL
 ALTER TABLE dbo.TDSTCompanySetupSystemIntranet
 ADD AllowSelfApproval bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_SelfApproval_Compat DEFAULT(0);

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemIntranet',N'DefaultApproverEmployeeID') IS NULL
 ALTER TABLE dbo.TDSTCompanySetupSystemIntranet ADD DefaultApproverEmployeeID bigint NULL;

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemIntranet',N'DefaultPublishDays') IS NULL
 ALTER TABLE dbo.TDSTCompanySetupSystemIntranet
 ADD DefaultPublishDays int NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemIntranet_PublishDays_Compat DEFAULT(30);
