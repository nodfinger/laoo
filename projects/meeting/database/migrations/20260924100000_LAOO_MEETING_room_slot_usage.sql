SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingSlotUsage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingSlotUsage
    (
        BookingSlotUsageID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingRoomBookingSlotUsage PRIMARY KEY,
        CompanyID bigint NOT NULL,
        BookingID bigint NOT NULL,
        BookingSlotID bigint NOT NULL,
        CheckInDate datetime2(3) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingSlotUsage_CheckInDate DEFAULT SYSUTCDATETIME(),
        CheckInByUserID bigint NOT NULL,
        ReturnDate datetime2(3) NULL,
        ReturnByUserID bigint NULL,
        ReturnRemark nvarchar(500) NULL,
        CONSTRAINT UX_TDADMeetingRoomBookingSlotUsage_Slot UNIQUE(CompanyID, BookingSlotID),
        CONSTRAINT FK_TDADMeetingRoomBookingSlotUsage_Booking
            FOREIGN KEY(BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID),
        CONSTRAINT FK_TDADMeetingRoomBookingSlotUsage_Slot
            FOREIGN KEY(BookingSlotID) REFERENCES dbo.TDADMeetingRoomBookingSlot(BookingSlotID),
        CONSTRAINT CK_TDADMeetingRoomBookingSlotUsage_Return
            CHECK((ReturnDate IS NULL AND ReturnByUserID IS NULL) OR
                  (ReturnDate IS NOT NULL AND ReturnByUserID IS NOT NULL))
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.TDADMeetingRoomBookingSlotUsage')
      AND name=N'IX_TDADMeetingRoomBookingSlotUsage_Company_Booking'
)
    CREATE INDEX IX_TDADMeetingRoomBookingSlotUsage_Company_Booking
        ON dbo.TDADMeetingRoomBookingSlotUsage(CompanyID, BookingID, BookingSlotID)
        INCLUDE(CheckInDate, ReturnDate, CheckInByUserID, ReturnByUserID);

COMMIT TRANSACTION;
