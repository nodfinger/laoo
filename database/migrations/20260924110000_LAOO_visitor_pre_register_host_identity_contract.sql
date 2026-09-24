-- Core metadata for Visitor pre-registration and approval-status screens.
SET XACT_ABORT ON;

DECLARE @VisitorProjectID bigint = (SELECT TOP (1) ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR' AND IsActive=1);
IF @VisitorProjectID IS NULL THROW 53130, N'Active Visitor project is required.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'32')
    THROW 53131, N'MenuGroup 32 is required for Visitor navigation.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'32001')
    THROW 53132, N'Menu 32001 is required.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'32002')
    THROW 53133, N'Menu 32002 is required.', 1;

UPDATE dbo.TDADMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'32' AND IsActive=0;

UPDATE dbo.TDADMainMenu
SET MenuGroupCode=N'32',MenuName=N'นัดหมายล่วงหน้า',ScreenType=1,
    RouteName=N'preRegister',RoutePath=N'/visitor/pre-register',IsVisible=1,IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE MenuCode=N'32001';

UPDATE dbo.TDADMainMenu
SET MenuGroupCode=N'32',MenuName=N'สถานะการอนุมัติ',ScreenType=3,
    RouteName=N'approvalStatus',RoutePath=N'/visitor/approval-status',IsVisible=1,IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE MenuCode=N'32002';

UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'32';
IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'32')
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(@VisitorProjectID,N'32',2,1,SYSUTCDATETIME());

MERGE dbo.TDADProjectMenu AS Target
USING (VALUES
    (@VisitorProjectID,N'32001',N'32',10,1),
    (@VisitorProjectID,N'32002',N'32',20,1)
) AS Source(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
ON Target.ProjectID=Source.ProjectID AND Target.MenuCode=Source.MenuCode
WHEN MATCHED THEN UPDATE SET MenuGroupCode=Source.MenuGroupCode,SortOrder=Source.SortOrder,IsActive=Source.IsActive,UpdateDate=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(Source.ProjectID,Source.MenuCode,Source.MenuGroupCode,Source.SortOrder,Source.IsActive,SYSUTCDATETIME());

UPDATE dbo.TDADPermission
SET ScreenNameTH=CASE ScreenCode WHEN N'32001' THEN N'นัดหมายล่วงหน้า' ELSE N'สถานะการอนุมัติ' END,
    ScreenNameEN=CASE ScreenCode WHEN N'32001' THEN N'Pre Registration' ELSE N'Approval Status' END,
    ActionNameTH=CASE ActionCode WHEN N'VIEW' THEN N'แสดง' WHEN N'CREATE' THEN N'เพิ่ม' WHEN N'EDIT' THEN N'แก้ไข' WHEN N'DELETE' THEN N'ลบ' ELSE ActionNameTH END,
    IsActive=CASE WHEN (ScreenCode=N'32001' AND ActionCode IN(N'VIEW',N'CREATE',N'EDIT',N'DELETE')) OR (ScreenCode=N'32002' AND ActionCode IN(N'VIEW',N'EDIT')) THEN 1 ELSE 0 END,
    ModifiedDate=SYSUTCDATETIME()
WHERE ProjectID=@VisitorProjectID AND ScreenCode IN(N'32001',N'32002');

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,IsActive,CreatedDate)
SELECT @VisitorProjectID,Source.ScreenCode,Source.ScreenNameTH,Source.ScreenNameEN,Source.ActionCode,Source.ActionNameTH,1,SYSUTCDATETIME()
FROM (VALUES
    (N'32001',N'นัดหมายล่วงหน้า',N'Pre Registration',N'VIEW',N'แสดง'),
    (N'32001',N'นัดหมายล่วงหน้า',N'Pre Registration',N'CREATE',N'เพิ่ม'),
    (N'32001',N'นัดหมายล่วงหน้า',N'Pre Registration',N'EDIT',N'แก้ไข'),
    (N'32001',N'นัดหมายล่วงหน้า',N'Pre Registration',N'DELETE',N'ลบ'),
    (N'32002',N'สถานะการอนุมัติ',N'Approval Status',N'VIEW',N'แสดง'),
    (N'32002',N'สถานะการอนุมัติ',N'Approval Status',N'EDIT',N'แก้ไข')
) AS Source(ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TDADPermission Target
    WHERE Target.ProjectID=@VisitorProjectID AND Target.ScreenCode=Source.ScreenCode AND Target.ActionCode=Source.ActionCode
);
