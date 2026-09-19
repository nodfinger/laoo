/* Training-owned tables only. Booking references are logical, not cross-project FKs.
   Definitions and immutable randomized attempts are versioned JSON documents.
   Images contain metadata only; file bytes are stored privately by the API. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'dbo.TDTRBookingExam', N'U') IS NULL
 BEGIN
  CREATE TABLE dbo.TDTRBookingExam (
   ExamID bigint IDENTITY PRIMARY KEY,
   CompanyID bigint NOT NULL,
   BookingID bigint NOT NULL,
   SectionCode varchar(4) NOT NULL,
   DefinitionJson nvarchar(max) NOT NULL,
   CreateBy bigint NOT NULL,
   CreateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   UpdateBy bigint NOT NULL,
   UpdateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   RowVersion rowversion NOT NULL,
   CONSTRAINT UQ_TDTRBookingExam UNIQUE(CompanyID, BookingID, SectionCode),
   CONSTRAINT CK_TDTRBookingExam_Section CHECK(SectionCode IN ('PRE','POST')),
   CONSTRAINT CK_TDTRBookingExam_Json CHECK(ISJSON(DefinitionJson)=1)
  );
 END;
 IF OBJECT_ID(N'dbo.TDTRBookingExamAttempt', N'U') IS NULL
 BEGIN
  CREATE TABLE dbo.TDTRBookingExamAttempt (
   AttemptID bigint IDENTITY PRIMARY KEY,
   ExamID bigint NOT NULL REFERENCES dbo.TDTRBookingExam(ExamID),
   CompanyID bigint NOT NULL,
   BookingParticipantID bigint NOT NULL,
   EmployeeCodeSnapshot nvarchar(100) NOT NULL,
   EmployeeNameSnapshot nvarchar(300) NOT NULL,
   SnapshotJson nvarchar(max) NOT NULL,
   AnswersJson nvarchar(max) NOT NULL DEFAULT N'[]',
   StartedDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   SubmittedDate datetime2(3) NULL,
   Score int NULL,
   MaxScore int NOT NULL,
   PassingPercent decimal(5,2) NOT NULL,
   Passed bit NULL,
   UpdateBy bigint NOT NULL,
   RowVersion rowversion NOT NULL,
   CONSTRAINT UQ_TDTRBookingExamAttempt UNIQUE(ExamID,BookingParticipantID),
   CONSTRAINT CK_TDTRBookingExamAttempt_Json CHECK(ISJSON(SnapshotJson)=1 AND ISJSON(AnswersJson)=1),
   CONSTRAINT CK_TDTRBookingExamAttempt_Score CHECK(MaxScore>0 AND (Score IS NULL OR Score BETWEEN 0 AND MaxScore)),
   CONSTRAINT CK_TDTRBookingExamAttempt_Threshold CHECK(PassingPercent BETWEEN 0 AND 100)
  );
  CREATE INDEX IX_TDTRBookingExamAttempt_Results ON dbo.TDTRBookingExamAttempt(CompanyID,ExamID,Score DESC,SubmittedDate);
 END;
 IF OBJECT_ID(N'dbo.TDTRBookingExamImage', N'U') IS NULL
 BEGIN
  CREATE TABLE dbo.TDTRBookingExamImage (
   ImageID uniqueidentifier PRIMARY KEY,
   CompanyID bigint NOT NULL,
   BookingID bigint NOT NULL,
   ContentType varchar(20) NOT NULL,
   ByteLength int NOT NULL,
   CreateBy bigint NOT NULL,
   CreateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   CONSTRAINT CK_TDTRBookingExamImage_Size CHECK(ByteLength>0 AND ByteLength<=1048576),
   CONSTRAINT CK_TDTRBookingExamImage_Type CHECK(ContentType IN ('image/jpeg','image/png','image/webp'))
  );
  CREATE INDEX IX_TDTRBookingExamImage_Booking ON dbo.TDTRBookingExamImage(CompanyID,BookingID);
 END;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
