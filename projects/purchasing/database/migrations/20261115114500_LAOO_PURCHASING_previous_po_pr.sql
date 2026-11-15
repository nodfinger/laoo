IF COL_LENGTH(N'dbo.TDAPPurchaseRequest', N'PreviousPONo') IS NULL
    ALTER TABLE dbo.TDAPPurchaseRequest ADD PreviousPONo nvarchar(100) NULL;

IF COL_LENGTH(N'dbo.TDAPPurchaseRequest', N'PreviousPRNo') IS NULL
    ALTER TABLE dbo.TDAPPurchaseRequest ADD PreviousPRNo nvarchar(100) NULL;
