SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @project IS NULL THROW 54230,N'Core project not found.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10011' AND (RouteName<>N'companyApprovalPattern' OR ScreenType<>3))
 THROW 54231,N'Menu code is already used.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10011')
BEGIN
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,RunData,AllowListDisplaySettings,CreateDate)
 VALUES(N'10011',N'10',N'รูปแบบการอนุมัติ',3,N'companyApprovalPattern',N'/company/approval-pattern',NULL,N'approval',50,1,1,1,0,0,SYSUTCDATETIME());
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@project AND MenuCode=N'10011')
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive) VALUES(@project,N'10011',N'10',50,1);
COMMIT;
