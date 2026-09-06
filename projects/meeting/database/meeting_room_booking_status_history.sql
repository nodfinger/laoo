USE [DBTDMeeting];
GO

/* Preserve every booking status transition for the approval history popup. */
IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingStatusHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingStatusHistory
    (
        BookingStatusHistoryID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingRoomBookingStatusHistory PRIMARY KEY,
        BookingID BIGINT NOT NULL,
        CompanyID BIGINT NOT NULL,
        FromStatus VARCHAR(20) NULL,
        ToStatus VARCHAR(20) NOT NULL,
        ChangedDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingStatusHistory_ChangedDate DEFAULT (SYSUTCDATETIME()),
        ChangedByUserID BIGINT NULL,
        Remark NVARCHAR(1000) NULL,
        ChangeSource VARCHAR(30) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingStatusHistory_Source DEFAULT ('SYSTEM'),
        CONSTRAINT FK_TDADMeetingRoomBookingStatusHistory_Booking
            FOREIGN KEY (BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
        CONSTRAINT CK_TDADMeetingRoomBookingStatusHistory_Status
            CHECK (ToStatus IN ('PENDING','APPROVED','REJECTED','CANCELLED'))
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBookingStatusHistory')
      AND name = N'IX_TDADMeetingRoomBookingStatusHistory_Booking'
)
    CREATE INDEX IX_TDADMeetingRoomBookingStatusHistory_Booking
        ON dbo.TDADMeetingRoomBookingStatusHistory(CompanyID, BookingID, ChangedDate, BookingStatusHistoryID)
        INCLUDE (FromStatus, ToStatus, ChangedByUserID, Remark, ChangeSource);
GO

/* Seed one baseline event for bookings created before this audit table existed. */
INSERT dbo.TDADMeetingRoomBookingStatusHistory
    (BookingID,CompanyID,FromStatus,ToStatus,ChangedDate,ChangedByUserID,ChangeSource)
SELECT B.BookingID,B.CompanyID,NULL,B.BookingStatus,B.CreateDate,B.CreateBy,'MIGRATION'
FROM dbo.TDADMeetingRoomBooking B
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADMeetingRoomBookingStatusHistory H
    WHERE H.BookingID=B.BookingID AND H.CompanyID=B.CompanyID
);
GO
