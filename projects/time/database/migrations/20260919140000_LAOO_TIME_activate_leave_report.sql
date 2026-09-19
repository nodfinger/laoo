SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1);
    IF @ProjectID IS NULL THROW 52930, N'ไม่พบ Project LAOO_TIME ที่ใช้งานอยู่', 1;

    UPDATE dbo.TDADMenuGroup
    SET IsActive=1, UpdateDate=SYSUTCDATETIME()
    WHERE MenuGroupCode=N'28';

    UPDATE dbo.TDADProjectMenuGroup
    SET IsActive=1, UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND MenuGroupCode=N'28';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=N'28')
        INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
        VALUES(@ProjectID,N'28',5,1,SYSUTCDATETIME());

    UPDATE dbo.TDADProjectMenu
    SET MenuGroupCode=N'28',SortOrder=120,IsActive=1,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID AND MenuCode=N'28012';

    IF NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode=N'28012')
        INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
        VALUES(@ProjectID,N'28012',N'28',120,1,SYSUTCDATETIME());

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
