SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'64002' AND ScreenType=2 AND IsActive=1 AND IsVisible=1)
    THROW 54100, N'AI system settings menu must be active before hiding agent settings.', 1;

UPDATE dbo.TDADMainMenu SET IsVisible=0
WHERE MenuCode=N'64003' AND ScreenType=2 AND RouteName=N'companyAiAgents';
