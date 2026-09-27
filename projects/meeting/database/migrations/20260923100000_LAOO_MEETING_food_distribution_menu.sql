SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @ProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_MEETING' AND IsActive=1
    ORDER BY ProjectID
);

IF @ProjectID IS NULL
    THROW 51000, 'Active LAOO_MEETING project was not found.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode='21007')
BEGIN
    INSERT dbo.TDADMainMenu
    (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate)
    VALUES
    ('21007','21',N'แจกอาหาร',2,N'meetingFoodDistribution',N'/company/meeting-food-distribution',N'MEETING_FOOD_DISTRIBUTION',N'restaurant',45,1,1,1,SYSDATETIME());
END
ELSE
BEGIN
    UPDATE dbo.TDADMainMenu
    SET MenuGroupCode='21',MenuName=N'แจกอาหาร',ScreenType=2,
        RouteName=N'meetingFoodDistribution',RoutePath=N'/company/meeting-food-distribution',
        FeatureCode=N'MEETING_FOOD_DISTRIBUTION',IconName=N'restaurant',SortOrder=45,
        IsVisible=1,IsFavoriteAllowed=1,IsActive=1,UpdateDate=SYSDATETIME()
    WHERE MenuCode='21007';
END;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode='21007')
    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
    VALUES(@ProjectID,'21007','21',45,1);
ELSE
    UPDATE dbo.TDADProjectMenu SET MenuGroupCode='21',SortOrder=45,IsActive=1
    WHERE ProjectID=@ProjectID AND MenuCode='21007';

IF NOT EXISTS (SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@ProjectID AND ScreenCode='21007' AND ActionCode='VIEW')
    INSERT dbo.TDADPermission
    (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    VALUES(@ProjectID,'21007',N'แจกอาหาร',N'Food distribution','VIEW',N'ดูข้อมูล',N'View',1,SYSDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@ProjectID AND ScreenCode='21007' AND ActionCode='EDIT')
    INSERT dbo.TDADPermission
    (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    VALUES(@ProjectID,'21007',N'แจกอาหาร',N'Food distribution','EDIT',N'บันทึกการแจก',N'Edit',1,SYSDATETIME());

UPDATE P SET P.IsActive=1
FROM dbo.TDADPermission P
WHERE P.ProjectID=@ProjectID AND P.ScreenCode='21007' AND P.ActionCode IN ('VIEW','EDIT');

COMMIT TRANSACTION;
