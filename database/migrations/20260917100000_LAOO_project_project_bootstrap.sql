/* Core-owned LAOO_PROJECT entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.TDADProject
    SET ProjectNameTH = N'ระบบบริหารโครงการ',
        ProjectNameEN = N'Project Management',
        DescriptionText = N'ระบบบริหารโครงการ งาน และงบประมาณ',
        ProjectType = N'BUSINESS',
        IconName = N'folder_managed_outlined',
        SortOrder = 110,
        IsExpandedDefault = 0,
        IsActive = 1,
        UpdateDate = SYSUTCDATETIME()
    WHERE ProjectCode = N'LAOO_PROJECT';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_PROJECT')
        INSERT dbo.TDADProject
            (ProjectCode, ProjectNameTH, ProjectNameEN, DescriptionText,
             IsActive, CreateDate, ProjectType, SortOrder, IconName, IsExpandedDefault)
        VALUES
            (N'LAOO_PROJECT', N'ระบบบริหารโครงการ', N'Project Management',
             N'ระบบบริหารโครงการ งาน และงบประมาณ',
             1, SYSUTCDATETIME(), N'BUSINESS', 110, N'folder_managed_outlined', 0);

    /* TDADCompanyProject is intentionally not seeded. */
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
