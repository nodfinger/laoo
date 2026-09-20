SET XACT_ABORT ON;
BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @Captions TABLE(MenuCode char(5) NOT NULL PRIMARY KEY, MenuName nvarchar(150) NOT NULL);
    INSERT @Captions(MenuCode, MenuName) VALUES
      (N'18001', N'ตั้งค่าระบบบริการ'),
      (N'22006', N'ตั้งค่าระบบห้องประชุม'),
      (N'36004', N'ตั้งค่าระบบผู้มาติดต่อ'),
      (N'37004', N'ตั้งค่าระบบอบรม'),
      (N'39010', N'ตั้งค่าระบบ 5ส');

    UPDATE dbo.TDADMenuGroup
    SET MenuGroupName = N'ตั้งค่าระบบบริการ', UpdateDate = SYSUTCDATETIME()
    WHERE AudienceType = N'C' AND MenuGroupCode = N'18';

    UPDATE menu
    SET MenuName = caption.MenuName, UpdateDate = SYSUTCDATETIME()
    FROM dbo.TDADMainMenu menu
    JOIN @Captions caption ON caption.MenuCode = menu.MenuCode;

    UPDATE permission
    SET ScreenNameTH = caption.MenuName, ModifiedDate = SYSUTCDATETIME()
    FROM dbo.TDADPermission permission
    JOIN @Captions caption ON caption.MenuCode = permission.ScreenCode;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;