-- Approved Core Person/Resident registry. The migration runner owns the
-- transaction, application lock, checksum and migration ledger.
SET XACT_ABORT ON;

DECLARE @CoreProjectID bigint =
(
    SELECT TOP (1) ProjectID FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO' AND IsActive=1
);
DECLARE @ServiceProjectID bigint =
(
    SELECT TOP (1) ProjectID FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_SERVICE' AND IsActive=1
);

IF @CoreProjectID IS NULL THROW 52800, N'Active Core project LAOO is required.', 1;
IF OBJECT_ID(N'dbo.TDADPerson',N'U') IS NULL THROW 52801, N'TDADPerson is required.', 1;
IF OBJECT_ID(N'dbo.TDADRoom',N'U') IS NULL THROW 52802, N'TDADRoom is required.', 1;

IF OBJECT_ID(N'dbo.TDADResident',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADResident
    (
        ResidentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADResident PRIMARY KEY,
        CompanyID bigint NOT NULL,
        PersonID bigint NOT NULL,
        RoomID bigint NOT NULL,
        StartDate date NOT NULL,
        EndDate date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADResident_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADResident_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDADResident_Person FOREIGN KEY(CompanyID,PersonID)
            REFERENCES dbo.TDADPerson(CompanyID,PersonID),
        CONSTRAINT FK_TDADResident_Room FOREIGN KEY(CompanyID,RoomID)
            REFERENCES dbo.TDADRoom(CompanyID,RoomID),
        CONSTRAINT UQ_TDADResident_Company_ID UNIQUE(CompanyID,ResidentID),
        CONSTRAINT UQ_TDADResident_Person_Room_Start UNIQUE(CompanyID,PersonID,RoomID,StartDate),
        CONSTRAINT CK_TDADResident_Date CHECK(EndDate IS NULL OR EndDate>=StartDate)
    );
    CREATE INDEX IX_TDADResident_Company_Active_Room
        ON dbo.TDADResident(CompanyID,IsActive,RoomID,PersonID);
END;

UPDATE dbo.TDADMenuGroup
SET MenuGroupName=N'บุคคลและองค์กร'
WHERE MenuGroupCode=N'13';

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'13002')
    INSERT dbo.TDADMainMenu
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
    VALUES
        (N'13002',N'13',N'ทะเบียนบุคคล',1,N'companyPersons',N'/company/persons',N'person_outline',20,1,1,1);
ELSE
    UPDATE dbo.TDADMainMenu
    SET MenuGroupCode=N'13',MenuName=N'ทะเบียนบุคคล',ScreenType=1,
        RouteName=N'companyPersons',RoutePath=N'/company/persons',IconName=N'person_outline',
        SortOrder=20,IsVisible=1,IsFavoriteAllowed=1,IsActive=1
    WHERE MenuCode=N'13002';

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'14004')
    INSERT dbo.TDADMainMenu
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
    VALUES
        (N'14004',N'14',N'ทะเบียนผู้พักอาศัย',1,N'assetResidents',N'/asset/residents',N'badge_outlined',40,1,1,1);
ELSE
    UPDATE dbo.TDADMainMenu
    SET MenuGroupCode=N'14',MenuName=N'ทะเบียนผู้พักอาศัย',ScreenType=1,
        RouteName=N'assetResidents',RoutePath=N'/asset/residents',IconName=N'badge_outlined',
        SortOrder=40,IsVisible=1,IsFavoriteAllowed=1,IsActive=1
    WHERE MenuCode=N'14004';

UPDATE dbo.TDADProjectMenuGroup
SET IsActive=1,
    SortOrder=CASE MenuGroupCode WHEN N'14' THEN 3 ELSE 4 END
WHERE ProjectID=@CoreProjectID AND MenuGroupCode IN(N'13',N'14');
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@CoreProjectID AND MenuGroupCode=N'13')
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive) VALUES(@CoreProjectID,N'13',4,1);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@CoreProjectID AND MenuGroupCode=N'14')
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive) VALUES(@CoreProjectID,N'14',3,1);

MERGE dbo.TDADProjectMenu AS T
USING (VALUES
    (@CoreProjectID,N'13002',N'13',20,1),
    (@CoreProjectID,N'14004',N'14',40,1)
) AS S(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
ON T.ProjectID=S.ProjectID AND T.MenuCode=S.MenuCode
WHEN MATCHED THEN UPDATE SET MenuGroupCode=S.MenuGroupCode,SortOrder=S.SortOrder,IsActive=S.IsActive
WHEN NOT MATCHED THEN INSERT(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(S.ProjectID,S.MenuCode,S.MenuGroupCode,S.SortOrder,S.IsActive);

IF @ServiceProjectID IS NOT NULL
BEGIN
    UPDATE dbo.TDADProjectMenu SET IsActive=0
    WHERE ProjectID=@ServiceProjectID AND MenuGroupCode IN(N'08',N'09');
    UPDATE dbo.TDADProjectMenuGroup SET IsActive=0
    WHERE ProjectID=@ServiceProjectID AND MenuGroupCode IN(N'08',N'09');

    UPDATE dbo.TDADProjectMenuGroup SET IsActive=1
    WHERE ProjectID=@ServiceProjectID AND MenuGroupCode=N'14';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ServiceProjectID AND MenuGroupCode=N'14')
        INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive)
        VALUES(@ServiceProjectID,N'14',201,1);

    MERGE dbo.TDADProjectMenu AS T
    USING (SELECT @ServiceProjectID,N'14004',N'14',40,1) AS S(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
    ON T.ProjectID=S.ProjectID AND T.MenuCode=S.MenuCode
    WHEN MATCHED THEN UPDATE SET MenuGroupCode=S.MenuGroupCode,SortOrder=S.SortOrder,IsActive=S.IsActive
    WHEN NOT MATCHED THEN INSERT(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
    VALUES(S.ProjectID,S.MenuCode,S.MenuGroupCode,S.SortOrder,S.IsActive);
END;

DECLARE @Permissions TABLE(ActionCode nvarchar(50),ActionNameTH nvarchar(100));
INSERT @Permissions VALUES(N'VIEW',N'แสดง'),(N'CREATE',N'เพิ่ม'),(N'EDIT',N'แก้ไข'),(N'DELETE',N'ลบ');

UPDATE P
SET ScreenNameTH=N'ทะเบียนบุคคล',ScreenNameEN=N'Person Registry',
    ActionNameTH=A.ActionNameTH,IsActive=1
FROM dbo.TDADPermission P
JOIN @Permissions A ON A.ActionCode=P.ActionCode
WHERE P.ProjectID=@CoreProjectID AND P.ScreenCode=N'13002';

UPDATE P
SET ScreenNameTH=N'ทะเบียนผู้พักอาศัย',ScreenNameEN=N'Resident Registry',
    ActionNameTH=A.ActionNameTH,IsActive=1
FROM dbo.TDADPermission P
JOIN @Permissions A ON A.ActionCode=P.ActionCode
WHERE P.ProjectID=@CoreProjectID AND P.ScreenCode=N'14004';

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,IsActive)
SELECT @CoreProjectID,N'13002',N'ทะเบียนบุคคล',N'Person Registry',A.ActionCode,A.ActionNameTH,1
FROM @Permissions A
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@CoreProjectID AND P.ScreenCode=N'13002' AND P.ActionCode=A.ActionCode);

INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,IsActive)
SELECT @CoreProjectID,N'14004',N'ทะเบียนผู้พักอาศัย',N'Resident Registry',A.ActionCode,A.ActionNameTH,1
FROM @Permissions A
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@CoreProjectID AND P.ScreenCode=N'14004' AND P.ActionCode=A.ActionCode);

IF @ServiceProjectID IS NOT NULL
BEGIN
    UPDATE P
    SET ScreenNameTH=N'ทะเบียนผู้พักอาศัย',ScreenNameEN=N'Resident Registry',
        ActionNameTH=A.ActionNameTH,IsActive=1
    FROM dbo.TDADPermission P
    JOIN @Permissions A ON A.ActionCode=P.ActionCode
    WHERE P.ProjectID=@ServiceProjectID AND P.ScreenCode=N'14004';

    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,IsActive)
    SELECT @ServiceProjectID,N'14004',N'ทะเบียนผู้พักอาศัย',N'Resident Registry',A.ActionCode,A.ActionNameTH,1
    FROM @Permissions A
    WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ServiceProjectID AND P.ScreenCode=N'14004' AND P.ActionCode=A.ActionCode);
END;

-- Visitor project menus remain unchanged and inactive.
-- No grants are created for non-admin users and no technical metadata is inserted.
