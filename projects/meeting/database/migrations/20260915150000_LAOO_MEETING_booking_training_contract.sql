/* Optional Training contract for Meeting bookings. No cross-project foreign keys. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'TrainingTypeID') IS NULL
        ALTER TABLE dbo.TDADMeetingRoomBooking ADD TrainingTypeID bigint NULL;
    IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'TrainingInstructorID') IS NULL
        ALTER TABLE dbo.TDADMeetingRoomBooking ADD TrainingInstructorID bigint NULL;
    IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'TrainingTypeNameSnapshot') IS NULL
        ALTER TABLE dbo.TDADMeetingRoomBooking ADD TrainingTypeNameSnapshot nvarchar(200) NULL;
    IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'TrainingInstructorNameSnapshot') IS NULL
        ALTER TABLE dbo.TDADMeetingRoomBooking ADD TrainingInstructorNameSnapshot nvarchar(200) NULL;
    IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'TrainingInstituteSnapshot') IS NULL
        ALTER TABLE dbo.TDADMeetingRoomBooking ADD TrainingInstituteSnapshot nvarchar(200) NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADMeetingRoomBooking') AND name=N'CK_TDADMeetingRoomBooking_TrainingFields')
        ALTER TABLE dbo.TDADMeetingRoomBooking ADD CONSTRAINT CK_TDADMeetingRoomBooking_TrainingFields CHECK
        (ActivityTypeCode='TRAINING' OR (TrainingTypeID IS NULL AND TrainingInstructorID IS NULL AND TrainingTypeNameSnapshot IS NULL AND TrainingInstructorNameSnapshot IS NULL AND TrainingInstituteSnapshot IS NULL));

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
