SET XACT_ABORT ON;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
    IF @ProjectID IS NULL THROW 54130, N'Active LAOO project is required.', 1;
    IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'01008' AND (MenuGroupCode<>N'01' OR ScreenType<>2 OR ISNULL(RouteName,N'')<>N'qrCodeGenerator' OR ISNULL(RoutePath,N'')<>N'/support/qr-code-generator'))
       THROW 54131, N'MenuCode 01008 conflicts with the QR generator route contract.', 1;
    IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode<>N'01008' AND (RouteName=N'qrCodeGenerator' OR RoutePath=N'/support/qr-code-generator'))
       THROW 54132, N'QR generator route conflicts with an existing menu.', 1;

    UPDATE dbo.TDADMainMenu
    SET MenuGroupCode=N'01',MenuName=N'สร้าง QR Code',ScreenType=2,
        RouteName=N'qrCodeGenerator',RoutePath=N'/support/qr-code-generator',
        FeatureCode=N'LAOO_QR_CODE_GENERATOR',IconName=N'qr_code_2_outlined',
        SortOrder=44,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,
        ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME()
    WHERE MenuCode=N'01008';
    IF @@ROWCOUNT=0
        INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
        VALUES(N'01008',N'01',N'สร้าง QR Code',2,N'qrCodeGenerator',N'/support/qr-code-generator',N'LAOO_QR_CODE_GENERATOR',N'qr_code_2_outlined',44,1,1,1,SYSUTCDATETIME(),0);

    UPDATE dbo.TDADProjectMenu
    SET MenuGroupCode=N'01',SortOrder=44,IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND MenuCode=N'01008';
    IF @@ROWCOUNT=0
        INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
        VALUES(@ProjectID,N'01008',N'01',44,1,SYSUTCDATETIME());

    UPDATE dbo.TDADPermission
    SET ScreenNameTH=N'สร้าง QR Code',ScreenNameEN=N'QR Code Generator',
        ActionNameTH=N'ใช้งาน',ActionNameEN=N'View',IsActive=1,ModifiedDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND ScreenCode=N'01008' AND ActionCode=N'VIEW';
    IF @@ROWCOUNT=0
        INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
        VALUES(@ProjectID,N'01008',N'สร้าง QR Code',N'QR Code Generator',N'VIEW',N'ใช้งาน',N'View',1,SYSUTCDATETIME());

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
