/*
  Core-owned LAOO_GATE_PASS entitlement bootstrap.
  Company enablement remains opt-in through TDADCompanyProject.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.TDADProject
    SET ProjectNameTH=N'ระบบนำทรัพย์สินออกนอกพื้นที่',
        ProjectNameEN=N'Gate Pass',
        DescriptionText=N'ระบบขออนุมัติและติดตามการนำทรัพย์สินออกนอกพื้นที่',
        ProjectType=N'BUSINESS',
        IconName=N'outbound_outlined',
        SortOrder=70,
        IsExpandedDefault=0,
        IsActive=1,
        UpdateDate=SYSUTCDATETIME()
    WHERE ProjectCode=N'LAOO_GATE_PASS';

    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_GATE_PASS')
        INSERT dbo.TDADProject
        (
            ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,
            IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault
        )
        VALUES
        (
            N'LAOO_GATE_PASS',N'ระบบนำทรัพย์สินออกนอกพื้นที่',N'Gate Pass',
            N'ระบบขออนุมัติและติดตามการนำทรัพย์สินออกนอกพื้นที่',
            1,SYSUTCDATETIME(),N'BUSINESS',70,N'outbound_outlined',0
        );

    /*
      TDADCompanyProject is intentionally not seeded. Partner/Company project
      assignment remains the only entitlement path.
    */

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
