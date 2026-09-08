IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'CancelRemark') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingRoomBooking ADD CancelRemark nvarchar(1000) NULL;
END;
