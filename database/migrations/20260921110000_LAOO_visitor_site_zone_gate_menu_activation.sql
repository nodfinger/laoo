-- Core metadata-only activation for Visitor MenuCode 33001.
-- Apply only through the transactional migration runner.
SET XACT_ABORT ON;

DECLARE @CoreProjectID bigint = (SELECT TOP (1) ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
DECLARE @VisitorProjectID bigint = (SELECT TOP (1) ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR' AND IsActive=1);
IF @CoreProjectID IS NULL THROW 53100, N'Active Core project LAOO is required.', 1;
IF @VisitorProjectID IS NULL THROW 53101, N'Active Visitor project LAOO_VISITOR is required.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'33001') THROW 53102, N'MenuCode 33001 does not exist.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'33001' AND MenuGroupCode<>N'33') THROW 53103, N'MenuCode 33001 is not in MenuGroup 33.', 1;

UPDATE dbo.TDADMainMenu
SET MenuGroupCode=N'33',MenuName=N'กำหนดจุดติดต่อ',ScreenType=1,
    RouteName=N'siteZoneGate',RoutePath=N'/visitor/site-zone-gate',IsVisible=1,IsActive=1
WHERE MenuCode=N'33001';

UPDATE dbo.TDADProjectMenuGroup SET IsActive=1
WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'33';
IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@VisitorProjectID AND MenuGroupCode=N'33')
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive) VALUES(@VisitorProjectID,N'33',3,1);

MERGE dbo.TDADProjectMenu AS T
USING (SELECT @VisitorProjectID ProjectID,N'33001' MenuCode,N'33' MenuGroupCode,1 SortOrder,1 IsActive) AS S
ON T.ProjectID=S.ProjectID AND T.MenuCode=S.MenuCode
WHEN MATCHED THEN UPDATE SET MenuGroupCode=S.MenuGroupCode,SortOrder=S.SortOrder,IsActive=S.IsActive
WHEN NOT MATCHED THEN INSERT(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(S.ProjectID,S.MenuCode,S.MenuGroupCode,S.SortOrder,S.IsActive);

DECLARE @Permissions TABLE(ActionCode nvarchar(50) NOT NULL,ActionNameTH nvarchar(100) NOT NULL);
INSERT @Permissions VALUES(N'VIEW',N'แสดง'),(N'CREATE',N'เพิ่ม'),(N'EDIT',N'แก้ไข'),(N'DELETE',N'ลบ');
UPDATE P SET ScreenNameTH=N'กำหนดจุดติดต่อ',ScreenNameEN=N'Site Zone Gate',ActionNameTH=A.ActionNameTH,IsActive=1
FROM dbo.TDADPermission P JOIN @Permissions A ON A.ActionCode=P.ActionCode
WHERE P.ProjectID=@VisitorProjectID AND P.ScreenCode=N'33001';
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,IsActive)
SELECT @VisitorProjectID,N'33001',N'กำหนดจุดติดต่อ',N'Site Zone Gate',A.ActionCode,A.ActionNameTH,1
FROM @Permissions A
WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@VisitorProjectID AND P.ScreenCode=N'33001' AND P.ActionCode=A.ActionCode);