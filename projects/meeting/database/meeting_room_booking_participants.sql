USE [DBTDMeeting];
GO

IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingParticipant', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingParticipant
    (
        BookingParticipantID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingRoomBookingParticipant PRIMARY KEY,
        BookingID BIGINT NOT NULL,
        CompanyID BIGINT NOT NULL,
        EmployeeID BIGINT NOT NULL,
        InvitationStatus VARCHAR(20) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingParticipant_Status DEFAULT ('PENDING'),
        InvitedDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingParticipant_InvitedDate DEFAULT (SYSUTCDATETIME()),
        InvitedByUserID BIGINT NOT NULL,
        ResponseDate DATETIME2(0) NULL,
        Remark NVARCHAR(1000) NULL,
        CONSTRAINT FK_TDADMeetingRoomBookingParticipant_Booking
            FOREIGN KEY (BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingRoomBookingParticipant_Employee
            FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT UX_TDADMeetingRoomBookingParticipant_Booking_Employee
            UNIQUE (BookingID, EmployeeID),
        CONSTRAINT CK_TDADMeetingRoomBookingParticipant_Status
            CHECK (InvitationStatus IN ('PENDING','ACCEPTED','DECLINED'))
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.TDADMeetingRoomBookingParticipant')
      AND name=N'IX_TDADMeetingRoomBookingParticipant_Employee'
)
    CREATE INDEX IX_TDADMeetingRoomBookingParticipant_Employee
        ON dbo.TDADMeetingRoomBookingParticipant(CompanyID,EmployeeID,InvitationStatus)
        INCLUDE (BookingID,InvitedDate);
GO
