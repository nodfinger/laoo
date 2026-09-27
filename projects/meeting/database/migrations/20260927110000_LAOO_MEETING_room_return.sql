IF OBJECT_ID(N'dbo.TDADMeetingRoomReturn',N'U') IS NULL
CREATE TABLE dbo.TDADMeetingRoomReturn(
    RoomReturnID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CompanyID bigint NOT NULL,
    BookingID bigint NOT NULL,
    BookingSlotID bigint NOT NULL,
    ReturnDate datetime2 NOT NULL CONSTRAINT DF_TDADMeetingRoomReturn_Date DEFAULT SYSUTCDATETIME(),
    ReturnByUserID bigint NOT NULL,
    Remark nvarchar(1000) NULL,
    RowVersion rowversion NOT NULL,
    CONSTRAINT UQ_TDADMeetingRoomReturn_Slot UNIQUE(CompanyID,BookingSlotID)
);
GO
CREATE INDEX IX_TDADMeetingRoomReturn_Booking ON dbo.TDADMeetingRoomReturn(CompanyID,BookingID,BookingSlotID);
