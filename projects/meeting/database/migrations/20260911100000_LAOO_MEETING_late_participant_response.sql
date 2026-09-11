SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDADMeetingRoomBookingParticipant', N'IsLateResponse') IS NULL
 ALTER TABLE dbo.TDADMeetingRoomBookingParticipant
 ADD IsLateResponse BIT NOT NULL
  CONSTRAINT DF_TDADMeetingRoomBookingParticipant_IsLateResponse DEFAULT(0) WITH VALUES;

IF COL_LENGTH(N'dbo.TDADMeetingRoomBookingParticipant', N'LateResponseReason') IS NULL
 ALTER TABLE dbo.TDADMeetingRoomBookingParticipant
 ADD LateResponseReason NVARCHAR(500) NULL;

IF COL_LENGTH(N'dbo.TDADMeetingRoomBookingParticipant', N'LateResponseAtUtc') IS NULL
 ALTER TABLE dbo.TDADMeetingRoomBookingParticipant
 ADD LateResponseAtUtc DATETIME2(0) NULL;

COMMIT TRANSACTION;
GO
