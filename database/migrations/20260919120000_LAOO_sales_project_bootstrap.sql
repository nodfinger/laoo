/* Core-owned LAOO_SALES entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบบริหารงานขาย',ProjectNameEN=N'Sales Management',DescriptionText=N'ระบบบริหารลูกค้าเป้าหมาย โอกาสการขาย และงานติดตาม',ProjectType=N'BUSINESS',IconName=N'trending_up_outlined',SortOrder=140,IsExpandedDefault=0,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_SALES';
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES') INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault) VALUES(N'LAOO_SALES',N'ระบบบริหารงานขาย',N'Sales Management',N'ระบบบริหารลูกค้าเป้าหมาย โอกาสการขาย และงานติดตาม',1,SYSUTCDATETIME(),N'BUSINESS',140,N'trending_up_outlined',0);
 /* TDADCompanyProject is intentionally not seeded. */
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
