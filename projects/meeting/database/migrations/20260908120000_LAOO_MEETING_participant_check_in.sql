-- One attendance record per participant and booking slot.
IF OBJECT_ID(N'dbo.TDADMeetingParticipantCheckIn', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingParticipantCheckIn (
  ParticipantCheckInID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
  CompanyID bigint NOT NULL,
  BookingParticipantID bigint NOT NULL,
  BookingSlotID bigint NOT NULL,
  CheckInDate datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  CheckInByUserID bigint NOT NULL,
  CheckInMethod varchar(20) NOT NULL,
  CONSTRAINT FK_MeetingCheckIn_Participant FOREIGN KEY (BookingParticipantID) REFERENCES dbo.TDADMeetingRoomBookingParticipant(BookingParticipantID),
  CONSTRAINT FK_MeetingCheckIn_Slot FOREIGN KEY (BookingSlotID) REFERENCES dbo.TDADMeetingRoomBookingSlot(BookingSlotID),
  CONSTRAINT UX_MeetingParticipantCheckIn UNIQUE (CompanyID, BookingParticipantID, BookingSlotID),
  CONSTRAINT CK_MeetingParticipantCheckIn_Method CHECK (CheckInMethod IN ('SELF','MANUAL'))
 );
END;
