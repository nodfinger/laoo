IF COL_LENGTH(N'dbo.TDGPGatePassItem',N'PurposeID') IS NULL
    ALTER TABLE dbo.TDGPGatePassItem ADD PurposeID bigint NULL;
IF COL_LENGTH(N'dbo.TDGPGatePassItem',N'Remark') IS NULL
    ALTER TABLE dbo.TDGPGatePassItem ADD Remark nvarchar(1000) NULL;
