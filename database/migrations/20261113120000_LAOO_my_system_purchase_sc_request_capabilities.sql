SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS(
  SELECT 1 FROM dbo.TDADMainMenu
  WHERE MenuCode=N'69002' AND ScreenType=4 AND IsActive=1
)
  THROW 54270,N'SC Request menu is missing or has changed.',1;

UPDATE dbo.TDADMainMenu
SET RunData=1,
    AllowPrint=1,
    AllowListDisplaySettings=1,
    UpdateDate=SYSUTCDATETIME()
WHERE MenuCode=N'69002';
