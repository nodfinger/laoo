SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'70002' AND ScreenType=4 AND RouteName=N'mySystemLegalDocumentRequest')
  THROW 54240,N'Legal document request menu definition is missing or has changed.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE MenuCode=N'70002' AND MenuGroupCode=N'70')
  THROW 54241,N'Legal document request project menu is missing.',1;

UPDATE dbo.TDADMainMenu SET IsActive=1,IsVisible=1,IsFavoriteAllowed=1,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'70002';
UPDATE dbo.TDADProjectMenu SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'70002';
