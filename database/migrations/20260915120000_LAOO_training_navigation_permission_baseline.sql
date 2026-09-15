/* Core-owned Training navigation and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
BEGIN TRANSACTION;

DECLARE @TrainingProjectID bigint =
(
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_TRAINING' AND IsActive=1
);
IF @TrainingProjectID IS NULL
    THROW 52880,N'Active LAOO_TRAINING project is required.',1;

DECLARE @MenuGroupCode char(2)=N'37';

UPDATE dbo.TDADMenuGroup
SET AudienceType=N'C',
    MenuGroupName=N'ข้อมูลหลักระบบอบรม',
    IconName=N'school_outlined',
    SortOrder=370,
    IsExpandedDefault=0,
    IsActive=1,
    ShowPermissionPoint=0,
    OpenOption=0,
    UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode=@MenuGroupCode;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode)
    INSERT dbo.TDADMenuGroup
    (
        AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,
        IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption
    )
    VALUES
    (
        N'C',@MenuGroupCode,N'ข้อมูลหลักระบบอบรม',N'school_outlined',370,
        0,1,SYSUTCDATETIME(),0,0
    );

DECLARE @Menus TABLE
(
    MenuCode char(5) PRIMARY KEY,
    MenuName nvarchar(150) NOT NULL,
    ScreenType int NOT NULL,
    RouteName nvarchar(150) NOT NULL,
    RoutePath nvarchar(300) NOT NULL,
    FeatureCode nvarchar(100) NOT NULL,
    IconName nvarchar(100) NOT NULL,
    SortOrder int NOT NULL
);
INSERT @Menus VALUES
    (N'37001',N'ประเภทการอบรม',1,N'trainingTypes',N'/company/training-types',N'TRAINING_TYPES',N'category_outlined',10),
    (N'37002',N'วิทยากร',1,N'trainingInstructors',N'/company/training-instructors',N'TRAINING_INSTRUCTORS',N'person_outline',20);

IF EXISTS
(
    SELECT 1
    FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target ON target.MenuCode=source.MenuCode
    WHERE target.ScreenType<>source.ScreenType
       OR ISNULL(target.RouteName,N'')<>source.RouteName
       OR ISNULL(target.RoutePath,N'')<>source.RoutePath
)
    THROW 52881,N'Training MenuCode conflicts with existing ScreenType or route.',1;

IF EXISTS
(
    SELECT 1
    FROM @Menus source
    INNER JOIN dbo.TDADMainMenu target
      ON (target.RouteName=source.RouteName OR target.RoutePath=source.RoutePath)
     AND target.MenuCode<>source.MenuCode
)
    THROW 52882,N'Training RouteName or RoutePath is already used.',1;

UPDATE target
SET target.MenuGroupCode=@MenuGroupCode,
    target.MenuName=source.MenuName,
    target.ScreenType=source.ScreenType,
    target.RouteName=source.RouteName,
    target.RoutePath=source.RoutePath,
    target.FeatureCode=source.FeatureCode,
    target.IconName=source.IconName,
    target.SortOrder=source.SortOrder,
    target.IsVisible=1,
    target.IsFavoriteAllowed=1,
    target.IsActive=1,
    target.ShowPermissionPoint=0,
    target.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADMainMenu target
INNER JOIN @Menus source ON source.MenuCode=target.MenuCode;

INSERT dbo.TDADMainMenu
(
    MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,
    IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint
)
SELECT source.MenuCode,@MenuGroupCode,source.MenuName,source.ScreenType,
       source.RouteName,source.RoutePath,source.FeatureCode,source.IconName,
       source.SortOrder,1,1,1,SYSUTCDATETIME(),0
FROM @Menus source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADMainMenu target WHERE target.MenuCode=source.MenuCode
);

UPDATE dbo.TDADProjectMenuGroup
SET SortOrder=1,IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE ProjectID=@TrainingProjectID AND MenuGroupCode=@MenuGroupCode;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADProjectMenuGroup
    WHERE ProjectID=@TrainingProjectID AND MenuGroupCode=@MenuGroupCode
)
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(@TrainingProjectID,@MenuGroupCode,1,1,SYSUTCDATETIME());

UPDATE target
SET target.MenuGroupCode=@MenuGroupCode,
    target.SortOrder=source.SortOrder,
    target.IsActive=1,
    target.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADProjectMenu target
INNER JOIN @Menus source ON source.MenuCode=target.MenuCode
WHERE target.ProjectID=@TrainingProjectID;

INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @TrainingProjectID,source.MenuCode,@MenuGroupCode,source.SortOrder,1,SYSUTCDATETIME()
FROM @Menus source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADProjectMenu target
    WHERE target.ProjectID=@TrainingProjectID AND target.MenuCode=source.MenuCode
);

UPDATE dbo.TDADProjectMenu
SET IsActive=0,UpdateDate=SYSUTCDATETIME()
WHERE MenuCode IN(N'37001',N'37002')
  AND ProjectID<>@TrainingProjectID
  AND IsActive=1;

DECLARE @Permissions TABLE
(
    ScreenCode nvarchar(50) NOT NULL,
    ScreenNameTH nvarchar(200) NOT NULL,
    ScreenNameEN nvarchar(200) NOT NULL,
    ActionCode nvarchar(50) NOT NULL,
    ActionNameTH nvarchar(200) NOT NULL,
    ActionNameEN nvarchar(200) NOT NULL,
    PRIMARY KEY(ScreenCode,ActionCode)
);
INSERT @Permissions VALUES
    (N'37001',N'ประเภทการอบรม',N'Training types',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'37001',N'ประเภทการอบรม',N'Training types',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
    (N'37001',N'ประเภทการอบรม',N'Training types',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'37001',N'ประเภทการอบรม',N'Training types',N'DELETE',N'ลบข้อมูล',N'Delete'),
    (N'37002',N'วิทยากร',N'Training instructors',N'VIEW',N'ดูข้อมูล',N'View'),
    (N'37002',N'วิทยากร',N'Training instructors',N'CREATE',N'เพิ่มข้อมูล',N'Create'),
    (N'37002',N'วิทยากร',N'Training instructors',N'EDIT',N'แก้ไขข้อมูล',N'Edit'),
    (N'37002',N'วิทยากร',N'Training instructors',N'DELETE',N'ลบข้อมูล',N'Delete');

UPDATE target
SET target.ScreenNameTH=source.ScreenNameTH,
    target.ScreenNameEN=source.ScreenNameEN,
    target.ActionNameTH=source.ActionNameTH,
    target.ActionNameEN=source.ActionNameEN,
    target.IsActive=1,
    target.ModifiedDate=SYSUTCDATETIME()
FROM dbo.TDADPermission target
INNER JOIN @Permissions source
  ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode
WHERE target.ProjectID=@TrainingProjectID;

UPDATE target
SET target.IsActive=0,target.ModifiedDate=SYSUTCDATETIME()
FROM dbo.TDADPermission target
LEFT JOIN @Permissions source
  ON source.ScreenCode=target.ScreenCode AND source.ActionCode=target.ActionCode
WHERE target.ProjectID=@TrainingProjectID
  AND target.ScreenCode IN(N'37001',N'37002')
  AND source.ScreenCode IS NULL;

INSERT dbo.TDADPermission
(
    ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,
    ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate
)
SELECT @TrainingProjectID,source.ScreenCode,source.ScreenNameTH,source.ScreenNameEN,
       source.ActionCode,source.ActionNameTH,source.ActionNameEN,1,SYSUTCDATETIME()
FROM @Permissions source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADPermission target
    WHERE target.ProjectID=@TrainingProjectID
      AND target.ScreenCode=source.ScreenCode
      AND target.ActionCode=source.ActionCode
);

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
