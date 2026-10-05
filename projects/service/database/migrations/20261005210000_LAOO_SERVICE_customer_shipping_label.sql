SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TDADMainMenu
        WHERE MenuCode=N'09001' AND ScreenType=1
    )
        THROW 59001, N'ไม่พบเมนู 09001 ข้อมูลลูกค้า ScreenType 1', 1;

    IF COL_LENGTH(N'dbo.TDARCustomer', N'ShippingLabelName') IS NULL
        ALTER TABLE dbo.TDARCustomer ADD ShippingLabelName nvarchar(200) NULL;

    IF COL_LENGTH(N'dbo.TDARCustomer', N'ShippingLabelAddress') IS NULL
        ALTER TABLE dbo.TDARCustomer ADD ShippingLabelAddress nvarchar(1000) NULL;

    IF COL_LENGTH(N'dbo.TDARCustomer', N'ShippingLabelPhone') IS NULL
        ALTER TABLE dbo.TDARCustomer ADD ShippingLabelPhone nvarchar(50) NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
