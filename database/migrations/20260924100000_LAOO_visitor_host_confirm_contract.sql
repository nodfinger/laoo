-- Core metadata for the Visitor host-confirm screen.
SET XACT_ABORT ON;

DECLARE @VisitorProjectID bigint = (SELECT TOP (1) ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR' AND IsActive=1);
IF @VisitorProjectID IS NULL THROW 53120, N'Active Visitor project is required.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'32')
    THROW 53121, N'MenuGroup 32 is required for Visitor navigation.', 1;

UPDATE dbo.TDADMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'32' AND IsActive=0;

IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'32003')
    UPDATE dbo.TDADMainMenu SET MenuGroupCode=N'32',MenuName=N'ยืนยันการเข้าพบ',ScreenType=2,
        RouteName=N'hostConfirm',RoutePath=N'/visitor/host-confirm',IconName=N'how_to_reg',SortOrder=30,
        IsVisible=1,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'32003';
ELSE
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate)
    VALUES(N'32003',N'32',N'ยืนยันการเข้าพบ',2,N'hostConfirm',N'/visitor/host-confirm',N'how_to_reg',30,1,1,1,SYSUTCDATETIME());

UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'32';
IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'32')
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(@VisitorProjectID,N'32',2,1,SYSUTCDATETIME());

MERGE dbo.TDADProjectMenu AS Target
USING (SELECT @VisitorProjectID ProjectID,N'32003' MenuCode,N'32' MenuGroupCode,30 SortOrder,1 IsActive) AS Source
ON Target.ProjectID=Source.ProjectID AND Target.MenuCode=Source.MenuCode
WHEN MATCHED THEN UPDATE SET MenuGroupCode=Source.MenuGroupCode,SortOrder=Source.SortOrder,IsActive=Source.IsActive,UpdateDate=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(Source.ProjectID,Source.MenuCode,Source.MenuGroupCode,Source.SortOrder,Source.IsActive,SYSUTCDATETIME());

UPDATE dbo.TDADPermission
SET ScreenNameTH=N'ยืนยันการเข้าพบ',ScreenNameEN=N'Host Confirmation',
    ActionNameTH=CASE ActionCode WHEN N'VIEW' THEN N'แสดง' WHEN N'EDIT' THEN N'แก้ไข' ELSE ActionNameTH END,
    IsActive=CASE WHEN ActionCode IN(N'VIEW',N'EDIT') THEN 1 ELSE 0 END,ModifiedDate=SYSUTCDATETIME()
WHERE ProjectID=@VisitorProjectID AND ScreenCode=N'32003';
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,IsActive,CreatedDate)
SELECT @VisitorProjectID,N'32003',N'ยืนยันการเข้าพบ',N'Host Confirmation',V.ActionCode,V.ActionNameTH,1,SYSUTCDATETIME()
FROM (VALUES(N'VIEW',N'แสดง'),(N'EDIT',N'แก้ไข')) V(ActionCode,ActionNameTH)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@VisitorProjectID AND P.ScreenCode=N'32003' AND P.ActionCode=V.ActionCode);
