/* Core-owned LAOO_SURVEY entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.TDADProject
    SET ProjectNameTH=N'ระบบแบบสอบถาม', ProjectNameEN=N'Survey',
        DescriptionText=N'ระบบสร้าง ส่ง และสรุปผลแบบสอบถาม', ProjectType=N'BUSINESS',
        IconName=N'quiz_outlined', SortOrder=90, IsExpandedDefault=0, IsActive=1,
        UpdateDate=SYSUTCDATETIME()
    WHERE ProjectCode=N'LAOO_SURVEY';
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SURVEY')
        INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault)
        VALUES(N'LAOO_SURVEY',N'ระบบแบบสอบถาม',N'Survey',N'ระบบสร้าง ส่ง และสรุปผลแบบสอบถาม',1,SYSUTCDATETIME(),N'BUSINESS',90,N'quiz_outlined',0);
    /* TDADCompanyProject is intentionally not seeded. */
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
