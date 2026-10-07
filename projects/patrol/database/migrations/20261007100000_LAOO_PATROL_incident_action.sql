SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PATROL' AND IsActive=1);
IF @ProjectID IS NULL THROW 57620,N'LAOO_PATROL project is required.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@ProjectID AND ScreenCode=N'56008' AND ActionCode=N'REPORT_INCIDENT')
BEGIN
    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @ProjectID,M.MenuCode,M.MenuName,M.RouteName,N'REPORT_INCIDENT',N'แจ้งเหตุ',N'Report incident',1,SYSUTCDATETIME()
    FROM dbo.TDADMainMenu M WHERE M.MenuCode=N'56008' AND M.IsActive=1;
END;