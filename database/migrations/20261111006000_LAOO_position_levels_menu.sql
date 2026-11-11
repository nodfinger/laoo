SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @project IS NULL THROW 54101,N'Core project not found.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10007' AND MenuGroupCode=N'10' AND ScreenType=2) THROW 54102,N'Supervisor menu not found.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10009' AND (RouteName<>N'companyPositionLevels' OR ScreenType<>2)) THROW 54103,N'Menu code is already used.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10009')
BEGIN
 UPDATE dbo.TDADMainMenu SET SortOrder=SortOrder+1 WHERE MenuGroupCode=N'10' AND SortOrder>=4;
 UPDATE dbo.TDADProjectMenu SET SortOrder=SortOrder+1 WHERE ProjectID=@project AND MenuGroupCode=N'10' AND SortOrder>=4;
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,RunData,AllowListDisplaySettings,CreateDate)
 VALUES(N'10009',N'10',N'กำหนดระดับตำแหน่งงาน',2,N'companyPositionLevels',N'/company/position-levels',N'SUPERVISOR_ASSIGNMENT',N'supervisor_account',4,1,1,1,0,0,SYSUTCDATETIME());
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@project AND MenuCode=N'10009')
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive) VALUES(@project,N'10009',N'10',4,1);
COMMIT;
