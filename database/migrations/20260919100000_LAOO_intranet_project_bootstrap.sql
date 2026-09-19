/* Core-owned LAOO_INTRANET entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.TDADProject
    SET ProjectNameTH = N'ระบบ Intranet',
        ProjectNameEN = N'Intranet',
        DescriptionText = N'ระบบสื่อสารและข้อมูลภายในองค์กร',
        ProjectType = N'BUSINESS',
        IconName = N'campaign_outlined',
        SortOrder = 120,
        IsExpandedDefault = 0,
        IsActive = 1,
        UpdateDate = SYSUTCDATETIME()
    WHERE ProjectCode = N'LAOO_INTRANET';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_INTRANET')
        INSERT dbo.TDADProject
            (ProjectCode, ProjectNameTH, ProjectNameEN, DescriptionText,
             IsActive, CreateDate, ProjectType, SortOrder, IconName, IsExpandedDefault)
        VALUES
            (N'LAOO_INTRANET', N'ระบบ Intranet', N'Intranet',
             N'ระบบสื่อสารและข้อมูลภายในองค์กร',
             1, SYSUTCDATETIME(), N'BUSINESS', 120, N'campaign_outlined', 0);

    /* TDADCompanyProject is intentionally not seeded. */
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO