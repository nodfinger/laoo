/*
  Core-owned Training entitlement bootstrap.
  Company enablement remains TDADCompanyProject and is managed by the existing
  Partner Company project workflow. No Company receives Training by default.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.TDADProject
    SET ProjectNameTH = N'ระบบอบรม',
        ProjectNameEN = N'Training System',
        DescriptionText = N'ระบบอบรมสำหรับหลักสูตร วิทยากร การประเมิน และแบบทดสอบ',
        ProjectType = N'BUSINESS',
        IconName = N'school_outlined',
        SortOrder = 60,
        IsExpandedDefault = 0,
        IsActive = 1,
        UpdateDate = SYSUTCDATETIME()
    WHERE ProjectCode = N'LAOO_TRAINING';

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADProject
        WHERE ProjectCode = N'LAOO_TRAINING'
    )
        INSERT dbo.TDADProject
        (
            ProjectCode, ProjectNameTH, ProjectNameEN, DescriptionText,
            IsActive, CreateDate, ProjectType, SortOrder, IconName,
            IsExpandedDefault
        )
        VALUES
        (
            N'LAOO_TRAINING', N'ระบบอบรม', N'Training System',
            N'ระบบอบรมสำหรับหลักสูตร วิทยากร การประเมิน และแบบทดสอบ',
            1, SYSUTCDATETIME(), N'BUSINESS', 60, N'school_outlined', 0
        );

    /*
      Intentionally no TDADMainMenu, TDADProjectMenu, TDADPermission, or
      TDADCompanyProject records are created here. Menu codes and ScreenType
      are defined only when a real Training feature is approved; entitlements
      are opt-in through the established Partner Company project flow.
    */

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
