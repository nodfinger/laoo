SET XACT_ABORT ON;
BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @Captions TABLE(MenuCode char(5) NOT NULL PRIMARY KEY, MenuName nvarchar(150) NOT NULL);
    INSERT @Captions(MenuCode, MenuName) VALUES
      (N'18001', N'ต ั ้ ง ค ่ า ร ะ บ บ ร ิ ก า ร'),
      (N'22006', N'ต ั ้ ง ค ่ า ร ะ บ บ ห ้ อ ง ป ร ะ ช ุ ม'),
      (N'36004', N'ต ั ้ ง ค ่ า ร ะ บ บ ผ ู ้ ม า ต ิ ด ต ่ อ'),
      (N'37004', N'ต ั ้ ง ค ่ า ร ะ บ บ อ บ ร ม'),
      (N'39010', N'ต ั ้ ง ค ่ า ร ะ บ บ');

    UPDATE dbo.TDADMenuGroup
    SET MenuGroupName = N'ต ั ้ ง ค ่ า ร ะ บ บ ร ิ ก า ร', UpdateDate = SYSUTCDATETIME()
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