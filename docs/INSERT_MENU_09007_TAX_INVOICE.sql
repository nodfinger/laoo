SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @GroupCode nvarchar(20)=N'09';

IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09007')
BEGIN
    UPDATE dbo.TDADMainMenu
       SET MenuGroupCode=@GroupCode,
           MenuName=N'ใบกำกับภาษี',
           ScreenType=4,
           RouteName=N'companyTaxInvoices',
           RoutePath=N'/company/tax-invoices',
           FeatureCode=NULL,
           IconName=N'receipt_long_outlined',
           IsFavoriteAllowed=1,
           IsActive=1,
           IsVisible=1,
           UpdateDate=SYSUTCDATETIME()
     WHERE MenuCode=N'09007';
END
ELSE
BEGIN
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
    SELECT N'09007',@GroupCode,N'ใบกำกับภาษี',4,N'companyTaxInvoices',N'/company/tax-invoices',NULL,N'receipt_long_outlined',
           ISNULL(MAX(SortOrder),0)+1,1,1,1
      FROM dbo.TDADMainMenu WHERE MenuGroupCode=@GroupCode;
END;

COMMIT TRANSACTION;
SELECT MenuCode,MenuName,ScreenType,RouteName,RoutePath FROM dbo.TDADMainMenu WHERE MenuCode=N'09007';
