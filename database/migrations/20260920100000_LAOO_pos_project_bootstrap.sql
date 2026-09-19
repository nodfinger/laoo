/* Core-owned LAOO_POS entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.TDADProject
    SET ProjectNameTH = N'ระบบขายหน้าร้าน', ProjectNameEN = N'Point of Sale',
        DescriptionText = N'ระบบขายหน้าร้าน จัดการจุดขาย เครื่องขาย กะเงินสด และรายงาน',
        ProjectType = N'BUSINESS', IconName = N'point_of_sale_outlined',
        SortOrder = 140, IsExpandedDefault = 0, IsActive = 1, UpdateDate = SYSUTCDATETIME()
    WHERE ProjectCode = N'LAOO_POS';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_POS')
        INSERT dbo.TDADProject
            (ProjectCode, ProjectNameTH, ProjectNameEN, DescriptionText, IsActive, CreateDate, ProjectType, SortOrder, IconName, IsExpandedDefault)
        VALUES
            (N'LAOO_POS', N'ระบบขายหน้าร้าน', N'Point of Sale', N'ระบบขายหน้าร้าน จัดการจุดขาย เครื่องขาย กะเงินสด และรายงาน',
             1, SYSUTCDATETIME(), N'BUSINESS', 140, N'point_of_sale_outlined', 0);

    /* TDADCompanyProject is intentionally not seeded. */
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO