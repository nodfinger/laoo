/* Allow any number of exam sets per booking and PRE/POST section. */
IF COL_LENGTH(N'dbo.TDTRBookingExam', N'SequenceNo') IS NULL
BEGIN
    ALTER TABLE dbo.TDTRBookingExam ADD SequenceNo int NULL;
    EXEC(N'UPDATE dbo.TDTRBookingExam SET SequenceNo = 1 WHERE SequenceNo IS NULL');
    EXEC(N'ALTER TABLE dbo.TDTRBookingExam ALTER COLUMN SequenceNo int NOT NULL');
END;
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDTRBookingExam') AND name=N'UQ_TDTRBookingExam')
    ALTER TABLE dbo.TDTRBookingExam DROP CONSTRAINT UQ_TDTRBookingExam;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDTRBookingExam') AND name=N'UQ_TDTRBookingExam_Sequence')
    EXEC(N'ALTER TABLE dbo.TDTRBookingExam ADD CONSTRAINT UQ_TDTRBookingExam_Sequence UNIQUE(CompanyID,BookingID,SectionCode,SequenceNo)');
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDTRBookingExam') AND name=N'CK_TDTRBookingExam_Sequence')
    EXEC(N'ALTER TABLE dbo.TDTRBookingExam ADD CONSTRAINT CK_TDTRBookingExam_Sequence CHECK(SequenceNo > 0)');
