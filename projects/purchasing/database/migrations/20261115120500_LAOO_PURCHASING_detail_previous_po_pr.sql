IF COL_LENGTH(N'dbo.TDAPPurchaseRequestDetail', N'PreviousPONo') IS NULL
    ALTER TABLE dbo.TDAPPurchaseRequestDetail ADD PreviousPONo nvarchar(100) NULL;

IF COL_LENGTH(N'dbo.TDAPPurchaseRequestDetail', N'PreviousPRNo') IS NULL
    ALTER TABLE dbo.TDAPPurchaseRequestDetail ADD PreviousPRNo nvarchar(100) NULL;
