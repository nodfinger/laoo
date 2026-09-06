USE [DBTDMeeting];
GO

/* MenuCode 13001 - Meeting room bookings. */
IF OBJECT_ID(N'dbo.TDADMeetingRoomBooking', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBooking
    (
        BookingID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingRoomBooking PRIMARY KEY,
        CompanyID BIGINT NOT NULL,
        BookingNo NVARCHAR(30) NULL,
        RoomID BIGINT NOT NULL,
        RequesterUserID BIGINT NOT NULL,
        RequesterEmployeeID BIGINT NULL,
        Subject NVARCHAR(300) NOT NULL,
        Description NVARCHAR(1000) NULL,
        AttendeeCount INT NOT NULL,
        BookingStatus VARCHAR(20) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBooking_Status DEFAULT ('PENDING'),
        ApprovalMode VARCHAR(20) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBooking_ApprovalMode DEFAULT ('NONE'),
        RequireAllApprovers BIT NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBooking_RequireAll DEFAULT (1),
        Remark NVARCHAR(1000) NULL,
        StatusRemark NVARCHAR(1000) NULL,
        CreateDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBooking_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy BIGINT NOT NULL,
        UpdateDate DATETIME2(0) NULL,
        UpdateBy BIGINT NULL,
        CancelDate DATETIME2(0) NULL,
        RowVersion ROWVERSION NOT NULL,
        CONSTRAINT FK_TDADMeetingRoomBooking_Room
            FOREIGN KEY (RoomID) REFERENCES dbo.TDADMeetingRoom(RoomID),
        CONSTRAINT FK_TDADMeetingRoomBooking_User
            FOREIGN KEY (RequesterUserID) REFERENCES dbo.TDADUser(UserID),
        CONSTRAINT FK_TDADMeetingRoomBooking_Employee
            FOREIGN KEY (RequesterEmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT CK_TDADMeetingRoomBooking_AttendeeCount
            CHECK (AttendeeCount > 0),
        CONSTRAINT CK_TDADMeetingRoomBooking_Status
            CHECK (BookingStatus IN ('PENDING','APPROVED','REJECTED','CANCELLED')),
        CONSTRAINT CK_TDADMeetingRoomBooking_ApprovalMode
            CHECK (ApprovalMode IN ('NONE','LINE_MANAGER','SELECTED'))
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBooking')
      AND name = N'UX_TDADMeetingRoomBooking_Company_No'
)
    CREATE UNIQUE INDEX UX_TDADMeetingRoomBooking_Company_No
        ON dbo.TDADMeetingRoomBooking(CompanyID, BookingNo)
        WHERE BookingNo IS NOT NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBooking')
      AND name = N'IX_TDADMeetingRoomBooking_Company_Requester'
)
    CREATE INDEX IX_TDADMeetingRoomBooking_Company_Requester
        ON dbo.TDADMeetingRoomBooking(CompanyID, RequesterUserID, BookingStatus);
GO

IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingSlot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingSlot
    (
        BookingSlotID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingRoomBookingSlot PRIMARY KEY,
        BookingID BIGINT NOT NULL,
        CompanyID BIGINT NOT NULL,
        RoomID BIGINT NOT NULL,
        BookingDate DATE NOT NULL,
        StartDateTime DATETIME2(0) NOT NULL,
        EndDateTime DATETIME2(0) NOT NULL,
        CreateDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingSlot_CreateDate DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_TDADMeetingRoomBookingSlot_Booking
            FOREIGN KEY (BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingRoomBookingSlot_Room
            FOREIGN KEY (RoomID) REFERENCES dbo.TDADMeetingRoom(RoomID),
        CONSTRAINT UX_TDADMeetingRoomBookingSlot_Booking_Start
            UNIQUE (BookingID, StartDateTime),
        CONSTRAINT CK_TDADMeetingRoomBookingSlot_DateTime
            CHECK (EndDateTime > StartDateTime AND BookingDate = CONVERT(DATE, StartDateTime))
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBookingSlot')
      AND name = N'IX_TDADMeetingRoomBookingSlot_Room_Time'
)
    CREATE INDEX IX_TDADMeetingRoomBookingSlot_Room_Time
        ON dbo.TDADMeetingRoomBookingSlot(CompanyID, RoomID, StartDateTime, EndDateTime)
        INCLUDE (BookingID, BookingDate);
GO

IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingApproval', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingApproval
    (
        BookingApprovalID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingRoomBookingApproval PRIMARY KEY,
        BookingID BIGINT NOT NULL,
        EmployeeID BIGINT NOT NULL,
        ApprovalOrder INT NOT NULL,
        ApprovalStatus VARCHAR(20) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingApproval_Status DEFAULT ('PENDING'),
        ActionDate DATETIME2(0) NULL,
        ActionByUserID BIGINT NULL,
        Remark NVARCHAR(1000) NULL,
        CreateDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomBookingApproval_CreateDate DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_TDADMeetingRoomBookingApproval_Booking
            FOREIGN KEY (BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingRoomBookingApproval_Employee
            FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT UX_TDADMeetingRoomBookingApproval_Booking_Employee
            UNIQUE (BookingID, EmployeeID),
        CONSTRAINT CK_TDADMeetingRoomBookingApproval_Order
            CHECK (ApprovalOrder > 0),
        CONSTRAINT CK_TDADMeetingRoomBookingApproval_Status
            CHECK (ApprovalStatus IN ('PENDING','APPROVED','REJECTED'))
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBookingApproval')
      AND name = N'IX_TDADMeetingRoomBookingApproval_Employee'
)
    CREATE INDEX IX_TDADMeetingRoomBookingApproval_Employee
        ON dbo.TDADMeetingRoomBookingApproval(EmployeeID, ApprovalStatus, ApprovalOrder)
        INCLUDE (BookingID);
GO

/* Store the login user who completed an approval decision. */
IF COL_LENGTH(N'dbo.TDADMeetingRoomBookingApproval', N'ActionByUserID') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingRoomBookingApproval
        ADD ActionByUserID BIGINT NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBookingApproval')
      AND name = N'IX_TDADMeetingRoomBookingApproval_ActionUser'
)
    CREATE INDEX IX_TDADMeetingRoomBookingApproval_ActionUser
        ON dbo.TDADMeetingRoomBookingApproval(ActionByUserID, ActionDate)
        INCLUDE (BookingID, ApprovalStatus);
GO
