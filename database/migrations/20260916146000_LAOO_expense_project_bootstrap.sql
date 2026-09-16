/* Core-owned LAOO_EXPENSE entitlement bootstrap. Company enablement is opt-in. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบบันทึกค่าใช้จ่าย',ProjectNameEN=N'Expense',DescriptionText=N'ระบบบันทึก เบิก และติดตามค่าใช้จ่าย',ProjectType=N'BUSINESS',IconName=N'receipt_long_outlined',SortOrder=100,IsExpandedDefault=0,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_EXPENSE';
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EXPENSE')
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault) VALUES(N'LAOO_EXPENSE',N'ระบบบันทึกค่าใช้จ่าย',N'Expense',N'ระบบบันทึก เบิก และติดตามค่าใช้จ่าย',1,SYSUTCDATETIME(),N'BUSINESS',100,N'receipt_long_outlined',0);
/* TDADCompanyProject is intentionally not seeded. */
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
