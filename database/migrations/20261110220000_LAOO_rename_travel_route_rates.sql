SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'67002' AND RouteName = N'travelRouteRates')
    THROW 54040, N'Travel route menu 67002 not found.', 1;

UPDATE dbo.TDADMainMenu
SET MenuName = N'ค่าเดินทางระหว่างจุดเหมาจ่าย'
WHERE MenuCode = N'67002' AND RouteName = N'travelRouteRates';

UPDATE dbo.TDADPermission
SET ScreenNameTH = N'ค่าเดินทางระหว่างจุดเหมาจ่าย'
WHERE ScreenCode = N'67002'
  AND ProjectID IN (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_MY');

COMMIT;
