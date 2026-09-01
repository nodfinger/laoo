/* MenuCode 09006: ใบส่งของ, ScreenType 4, Customer only */
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @Group char(2)=N'09';
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09006')
 UPDATE dbo.TDADMainMenu SET MenuName=N'ใบส่งของ',MenuGroupCode=@Group,
  RouteName=N'companyDeliveryNotes',RoutePath=N'/company/delivery-notes',ScreenType=4,
  FeatureCode=NULL,IconName=N'local_shipping_outlined',IsFavoriteAllowed=1,IsActive=1,IsVisible=1
 WHERE MenuCode=N'09006';
ELSE
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
 SELECT N'09006',@Group,N'ใบส่งของ',4,N'companyDeliveryNotes',N'/company/delivery-notes',NULL,N'local_shipping_outlined',
  ISNULL(MAX(SortOrder),0)+1,1,1,1 FROM dbo.TDADMainMenu WHERE MenuGroupCode=@Group;
COMMIT TRANSACTION;
