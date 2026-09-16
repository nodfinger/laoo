/* Core-owned LAOO_5S entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.TDADProject
    SET ProjectNameTH=N'ระบบตรวจ 5ส',
        ProjectNameEN=N'5S Inspection',
        DescriptionText=N'ระบบตรวจและติดตามผล 5ส ภายในองค์กร',
        ProjectType=N'BUSINESS',
        IconName=N'fact_check_outlined',
        SortOrder=80,
        IsExpandedDefault=0,
        IsActive=1,
        UpdateDate=SYSUTCDATETIME()
    WHERE ProjectCode=N'LAOO_5S';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_5S')
        INSERT dbo.TDADProject
        (
            ProjectCode, ProjectNameTH, ProjectNameEN, DescriptionText,
            IsActive, CreateDate, ProjectType, SortOrder, IconName, IsExpandedDefault
        )
        VALUES
        (
            N'LAOO_5S', N'ระบบตรวจ 5ส', N'5S Inspection',
            N'ระบบตรวจและติดตามผล 5ส ภายในองค์กร',
            1, SYSUTCDATETIME(), N'BUSINESS', 80, N'fact_check_outlined', 0
        );

    /* TDADCompanyProject is intentionally never seeded by this migration. */
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
