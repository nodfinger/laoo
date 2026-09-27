SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF COL_LENGTH(N'dbo.TDTRBookingExam', N'SequenceNo') IS NULL
  ALTER TABLE dbo.TDTRBookingExam ADD SequenceNo int NULL;
 UPDATE dbo.TDTRBookingExam SET SequenceNo=1 WHERE SequenceNo IS NULL;
 ALTER TABLE dbo.TDTRBookingExam ALTER COLUMN SequenceNo int NOT NULL;
 IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTRBookingExam') AND name=N'UQ_TDTRBookingExam')
  ALTER TABLE dbo.TDTRBookingExam DROP CONSTRAINT UQ_TDTRBookingExam;
 IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTRBookingExam') AND name=N'UQ_TDTRBookingExam_Sequence')
  ALTER TABLE dbo.TDTRBookingExam ADD CONSTRAINT UQ_TDTRBookingExam_Sequence UNIQUE(CompanyID,BookingID,SectionCode,SequenceNo);
 IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTRBookingExam') AND name=N'IX_TDTRBookingExam_Order')
  CREATE INDEX IX_TDTRBookingExam_Order ON dbo.TDTRBookingExam(CompanyID,BookingID,SectionCode,SequenceNo);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
