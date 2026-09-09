IF OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrder', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingBookingFoodOrder
    (
        BookingFoodOrderID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingFoodOrder PRIMARY KEY,
        CompanyID BIGINT NOT NULL,
        BookingID BIGINT NOT NULL,
        BookingParticipantID BIGINT NOT NULL,
        OrderedForEmployeeID BIGINT NOT NULL,
        OrderedByUserID BIGINT NOT NULL,
        CreateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADMeetingBookingFoodOrder_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy BIGINT NOT NULL,
        UpdateDate DATETIME2(0) NULL,
        UpdateBy BIGINT NULL,
        -- Booking already cascades through Participant; a second path is rejected by SQL Server.
        CONSTRAINT FK_TDADMeetingBookingFoodOrder_Booking FOREIGN KEY (BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID),
        CONSTRAINT FK_TDADMeetingBookingFoodOrder_Participant FOREIGN KEY (BookingParticipantID) REFERENCES dbo.TDADMeetingRoomBookingParticipant(BookingParticipantID) ON DELETE CASCADE,
        CONSTRAINT UX_TDADMeetingBookingFoodOrder_Participant UNIQUE (CompanyID, BookingParticipantID)
    );
    CREATE INDEX IX_TDADMeetingBookingFoodOrder_Booking ON dbo.TDADMeetingBookingFoodOrder (CompanyID, BookingID);
END;
GO
IF OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrderDetail', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingBookingFoodOrderDetail
    (
        BookingFoodOrderDetailID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingFoodOrderDetail PRIMARY KEY,
        BookingFoodOrderID BIGINT NOT NULL,
        FoodID BIGINT NOT NULL,
        Quantity INT NOT NULL,
        CreateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADMeetingBookingFoodOrderDetail_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy BIGINT NOT NULL,
        CONSTRAINT FK_TDADMeetingBookingFoodOrderDetail_Order FOREIGN KEY (BookingFoodOrderID) REFERENCES dbo.TDADMeetingBookingFoodOrder(BookingFoodOrderID) ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingBookingFoodOrderDetail_Food FOREIGN KEY (FoodID) REFERENCES dbo.TDADMeetingFood(FoodID),
        CONSTRAINT CK_TDADMeetingBookingFoodOrderDetail_Quantity CHECK (Quantity BETWEEN 1 AND 99),
        CONSTRAINT UX_TDADMeetingBookingFoodOrderDetail_Order_Food UNIQUE (BookingFoodOrderID, FoodID)
    );
END;
