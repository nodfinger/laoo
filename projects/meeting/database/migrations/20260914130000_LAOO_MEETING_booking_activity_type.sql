IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'ActivityTypeCode') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingRoomBooking
        ADD ActivityTypeCode VARCHAR(20) NOT NULL CONSTRAINT DF_TDADMeetingRoomBooking_ActivityTypeCode DEFAULT ('MEETING') WITH VALUES;
END;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADMeetingRoomBooking') AND name=N'CK_TDADMeetingRoomBooking_ActivityTypeCode')
    ALTER TABLE dbo.TDADMeetingRoomBooking ADD CONSTRAINT CK_TDADMeetingRoomBooking_ActivityTypeCode CHECK (ActivityTypeCode IN ('MEETING','TRAINING'));
GO
