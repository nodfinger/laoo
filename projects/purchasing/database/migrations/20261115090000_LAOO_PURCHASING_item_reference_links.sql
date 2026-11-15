IF COL_LENGTH(N'dbo.TDAPPurchaseRequestDetail', N'ReferenceUrl1') IS NULL
    ALTER TABLE dbo.TDAPPurchaseRequestDetail ADD ReferenceUrl1 nvarchar(2048) NULL;
IF COL_LENGTH(N'dbo.TDAPPurchaseRequestDetail', N'ReferenceUrl2') IS NULL
    ALTER TABLE dbo.TDAPPurchaseRequestDetail ADD ReferenceUrl2 nvarchar(2048) NULL;
IF COL_LENGTH(N'dbo.TDAPPurchaseRequestDetail', N'ReferenceUrl3') IS NULL
    ALTER TABLE dbo.TDAPPurchaseRequestDetail ADD ReferenceUrl3 nvarchar(2048) NULL;
