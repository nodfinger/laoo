/* Core-owned LAOO_VOTE entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.TDADProject
    SET ProjectNameTH = N'ระบบโหวต', ProjectNameEN = N'Vote',
        DescriptionText = N'ระบบสร้างหัวข้อ ลงคะแนน และสรุปผลการโหวต',
        ProjectType = N'BUSINESS', IconName = N'how_to_vote_outlined',
        SortOrder = 130, IsExpandedDefault = 0, IsActive = 1, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectCode = N'LAOO_VOTE';
    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_VOTE')
        INSERT dbo.TDADProject
            (ProjectCode, ProjectNameTH, ProjectNameEN, DescriptionText, IsActive, CreateDate, ProjectType, SortOrder, IconName, IsExpandedDefault)
        VALUES
            (N'LAOO_VOTE', N'ระบบโหวต', N'Vote', N'ระบบสร้างหัวข้อ ลงคะแนน และสรุปผลการโหวต',
             1, SYSUTCDATETIME(), N'BUSINESS', 130, N'how_to_vote_outlined', 0);
    /* TDADCompanyProject is intentionally not seeded. */
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO