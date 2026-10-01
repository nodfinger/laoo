SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES' AND IsActive=1);
  IF @ProjectID IS NULL THROW 56310,N'Active LAOO_SALES project is required.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'45001' AND ScreenType=2 AND RouteName=N'salesSettings' AND RoutePath=N'/company/sales-settings') THROW 56311,N'Sales settings metadata contract is invalid.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=N'45')
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,N'45',1,1,SYSUTCDATETIME());
  ELSE UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=N'45';
  IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode=N'45001')
    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,N'45001',N'45',10,1,SYSUTCDATETIME());
  ELSE UPDATE dbo.TDADProjectMenu SET MenuGroupCode=N'45',SortOrder=10,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode=N'45001';
  IF NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@ProjectID AND ScreenCode=N'45001' AND ActionCode=N'EDIT')
    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    VALUES(@ProjectID,N'45001',N'ตั้งค่าระบบขาย',N'SALES_SETTINGS',N'EDIT',N'แก้ไข',N'EDIT',1,SYSUTCDATETIME());
  ELSE UPDATE dbo.TDADPermission SET IsActive=1,ModifiedDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND ScreenCode=N'45001' AND ActionCode=N'EDIT';
  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO
