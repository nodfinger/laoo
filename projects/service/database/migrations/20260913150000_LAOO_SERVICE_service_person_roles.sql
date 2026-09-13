/* Service-owned role for a shared Company Person. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDADPerson', N'U') IS NULL
        THROW 52940, N'TDADPerson is required before Service Person roles.', 1;

    IF OBJECT_ID(N'dbo.TDADServiceCustomer', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDADServiceCustomer
        (
            ServiceCustomerID bigint IDENTITY(1,1) NOT NULL
                CONSTRAINT PK_TDADServiceCustomer PRIMARY KEY,
            CompanyID bigint NOT NULL,
            PersonID bigint NOT NULL,
            IsActive bit NOT NULL
                CONSTRAINT DF_TDADServiceCustomer_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL
                CONSTRAINT DF_TDADServiceCustomer_CreateDate DEFAULT(SYSUTCDATETIME()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDADServiceCustomer_Person FOREIGN KEY(CompanyID, PersonID)
                REFERENCES dbo.TDADPerson(CompanyID, PersonID),
            CONSTRAINT UQ_TDADServiceCustomer_Company_Person UNIQUE(CompanyID, PersonID),
            CONSTRAINT UQ_TDADServiceCustomer_Company_ID UNIQUE(CompanyID, ServiceCustomerID)
        );

        CREATE INDEX IX_TDADServiceCustomer_Company_Active_Person
            ON dbo.TDADServiceCustomer(CompanyID, IsActive, PersonID);
    END;

    DECLARE @ServiceProjectID bigint =
    (
        SELECT TOP (1) ProjectID FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO_SERVICE' AND IsActive=1
    );
    DECLARE @CoreProjectID bigint =
    (
        SELECT TOP (1) ProjectID FROM dbo.TDADProject
        WHERE ProjectCode=N'LAOO' AND IsActive=1
    );
    IF @ServiceProjectID IS NULL
        THROW 52941, N'Active LAOO_SERVICE project is required.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.TDADMainMenu
        WHERE MenuCode<>N'14004'
          AND (RouteName=N'servicePersons' OR RoutePath=N'/service/persons')
    )
        THROW 52942, N'Service Person route is already used by another menu.', 1;

    UPDATE dbo.TDADMainMenu
    SET MenuGroupCode=N'14', MenuName=N'ทะเบียนบุคคล', ScreenType=1,
        RouteName=N'servicePersons', RoutePath=N'/service/persons',
        FeatureCode=N'SERVICE_PERSONS', IconName=N'person_outline', SortOrder=40,
        IsVisible=1, IsFavoriteAllowed=1, IsActive=1, ShowPermissionPoint=1,
        UpdateDate=SYSUTCDATETIME()
    WHERE MenuCode=N'14004';

    IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'14004')
        INSERT dbo.TDADMainMenu
        (
            MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,
            FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,
            IsActive,CreateDate,ShowPermissionPoint
        )
        VALUES
        (
            N'14004',N'14',N'ทะเบียนบุคคล',1,N'servicePersons',N'/service/persons',
            N'SERVICE_PERSONS',N'person_outline',40,1,1,1,SYSUTCDATETIME(),1
        );

    UPDATE dbo.TDADProjectMenuGroup
    SET IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ServiceProjectID AND MenuGroupCode=N'14';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ServiceProjectID AND MenuGroupCode=N'14')
        INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
        VALUES(@ServiceProjectID,N'14',201,1,SYSUTCDATETIME());

    UPDATE dbo.TDADProjectMenu
    SET MenuGroupCode=N'14',SortOrder=40,IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ServiceProjectID AND MenuCode=N'14004';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ServiceProjectID AND MenuCode=N'14004')
        INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
        VALUES(@ServiceProjectID,N'14004',N'14',40,1,SYSUTCDATETIME());

    IF @CoreProjectID IS NOT NULL
    BEGIN
        UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME()
        WHERE ProjectID=@CoreProjectID AND MenuCode=N'14004';
        UPDATE dbo.TDADPermission SET IsActive=0
        WHERE ProjectID=@CoreProjectID AND ScreenCode=N'14004';
    END;

    DECLARE @Actions TABLE(ActionCode nvarchar(50),NameTH nvarchar(100),NameEN nvarchar(100));
    INSERT @Actions VALUES(N'VIEW',N'แสดง',N'View'),(N'CREATE',N'เพิ่ม',N'Create'),(N'EDIT',N'แก้ไข',N'Edit');
    UPDATE P SET ScreenNameTH=N'ทะเบียนบุคคล',ScreenNameEN=N'Service Person Registry',
        ActionNameTH=A.NameTH,ActionNameEN=A.NameEN,IsActive=1
    FROM dbo.TDADPermission P JOIN @Actions A ON A.ActionCode=P.ActionCode
    WHERE P.ProjectID=@ServiceProjectID AND P.ScreenCode=N'14004';
    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @ServiceProjectID,N'14004',N'ทะเบียนบุคคล',N'Service Person Registry',A.ActionCode,A.NameTH,A.NameEN,1,SYSUTCDATETIME()
    FROM @Actions A WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADPermission P
        WHERE P.ProjectID=@ServiceProjectID AND P.ScreenCode=N'14004' AND P.ActionCode=A.ActionCode
    );
    UPDATE dbo.TDADPermission SET IsActive=0
    WHERE ProjectID=@ServiceProjectID AND ScreenCode=N'14004' AND ActionCode NOT IN(N'VIEW',N'CREATE',N'EDIT');

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADUserPermissionPointName
        WHERE MenuCode=N'14004' AND PermissionPointCode=N'PERSON_EDIT'
    )
        INSERT dbo.TDADUserPermissionPointName
            (MenuCode,PermissionPointCode,PermissionPointName,PermissionPointDescription,SortOrder,IsActive)
        SELECT N'14004',N'PERSON_EDIT',N'แก้ไขข้อมูลบุคคลกลาง',
               N'อนุญาตให้แก้ชื่อ ชื่อเล่น โทรศัพท์ อีเมล และสถานะที่ระบบอื่นใช้ร่วมกัน',
               ISNULL(MAX(SortOrder),0)+1,1
        FROM dbo.TDADUserPermissionPointName WHERE MenuCode=N'14004';
    ELSE
        UPDATE dbo.TDADUserPermissionPointName
        SET PermissionPointName=N'แก้ไขข้อมูลบุคคลกลาง',
            PermissionPointDescription=N'อนุญาตให้แก้ชื่อ ชื่อเล่น โทรศัพท์ อีเมล และสถานะที่ระบบอื่นใช้ร่วมกัน',
            IsActive=1,UpdatedDate=SYSUTCDATETIME()
        WHERE MenuCode=N'14004' AND PermissionPointCode=N'PERSON_EDIT';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
