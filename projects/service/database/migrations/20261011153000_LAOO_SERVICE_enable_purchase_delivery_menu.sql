SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF NOT EXISTS(
    SELECT 1 FROM dbo.TDADMainMenu
    WHERE MenuCode=N'09009' AND ScreenType=4
      AND RouteName=N'companyPurchaseDeliveries'
      AND RoutePath=N'/company/purchase-deliveries'
      AND IsActive=1
)
    THROW 59130,N'Purchase delivery menu 09009 metadata is missing or conflicts with its route contract',1;

IF NOT EXISTS(
    SELECT 1 FROM dbo.TDADProject P
    JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID
    WHERE P.ProjectCode=N'LAOO' AND P.IsActive=1
      AND PM.MenuCode=N'09009' AND PM.IsActive=1
)
    THROW 59131,N'Purchase delivery menu 09009 is not mapped to the active LAOO project',1;

UPDATE dbo.TDADMainMenu
SET IsVisible=1
WHERE MenuCode=N'09009' AND IsVisible=0;

COMMIT TRANSACTION;
