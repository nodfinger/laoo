SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'70002' AND IsActive=1 AND IsVisible=1 AND ScreenType=4)
  THROW 54250,N'Visible legal document request menu is required.',1;
UPDATE dbo.TDADMainMenu
SET AllowPrint=1,
    AllowListDisplaySettings=1,
    AllowDataAccessSettings=1,
    AllowExport=0,
    RequiresApproval=1,
    UpdateDate=SYSUTCDATETIME()
WHERE MenuCode=N'70002';
