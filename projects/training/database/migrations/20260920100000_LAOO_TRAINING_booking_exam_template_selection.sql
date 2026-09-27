/* A booking keeps an immutable copy of the selected reusable test template. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF COL_LENGTH(N'dbo.TDTRBookingExam', N'TrainingTestTemplateID') IS NULL
  ALTER TABLE dbo.TDTRBookingExam ADD TrainingTestTemplateID bigint NULL;
 IF COL_LENGTH(N'dbo.TDTRBookingExam', N'TrainingTestTemplateCodeSnapshot') IS NULL
  ALTER TABLE dbo.TDTRBookingExam ADD TrainingTestTemplateCodeSnapshot nvarchar(30) NULL;
 IF COL_LENGTH(N'dbo.TDTRBookingExam', N'TrainingTestTemplateNameSnapshot') IS NULL
  ALTER TABLE dbo.TDTRBookingExam ADD TrainingTestTemplateNameSnapshot nvarchar(200) NULL;
 IF COL_LENGTH(N'dbo.TDTRBookingExam', N'TrainingTestTemplateVersionNo') IS NULL
  ALTER TABLE dbo.TDTRBookingExam ADD TrainingTestTemplateVersionNo int NULL;
 IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTRBookingExam') AND name=N'IX_TDTRBookingExam_Template')
  CREATE INDEX IX_TDTRBookingExam_Template ON dbo.TDTRBookingExam(CompanyID,TrainingTestTemplateID);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
