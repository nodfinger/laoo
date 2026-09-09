-- Requires participant_food_orders and participant_check_in. Do not run independently.
-- Receipt totals belong to an order detail across ALL slots, not to a per-slot allowance.
IF OBJECT_ID(N'dbo.TDADMeetingParticipantCheckIn',N'U') IS NULL
 OR OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrderDetail',N'U') IS NULL
 THROW 51000, 'Install Meeting food orders and participant check-in first.', 1;

IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADMeetingParticipantCheckIn') AND name=N'CK_MeetingParticipantCheckIn_Method')
 ALTER TABLE dbo.TDADMeetingParticipantCheckIn DROP CONSTRAINT CK_MeetingParticipantCheckIn_Method;
ALTER TABLE dbo.TDADMeetingParticipantCheckIn WITH CHECK ADD CONSTRAINT CK_MeetingParticipantCheckIn_Method
 CHECK(CheckInMethod IN ('SELF','MANUAL','QR_SELF','QR_STAFF'));

IF OBJECT_ID(N'dbo.TDADMeetingFoodReceipt',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingFoodReceipt
 (
  FoodReceiptID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingFoodReceipt PRIMARY KEY,
  CompanyID bigint NOT NULL,
  BookingFoodOrderDetailID bigint NOT NULL,
  ParticipantCheckInID bigint NOT NULL,
  ReceivedQuantity int NOT NULL,
  ReceivedByUserID bigint NOT NULL,
  ReceivedAtUtc datetime2(7) NOT NULL,
  ReceiptMethod varchar(20) NOT NULL,
  CONSTRAINT UX_MeetingFoodReceipt_Detail UNIQUE(BookingFoodOrderDetailID),
  CONSTRAINT FK_MeetingFoodReceipt_Detail FOREIGN KEY(BookingFoodOrderDetailID) REFERENCES dbo.TDADMeetingBookingFoodOrderDetail(BookingFoodOrderDetailID),
  CONSTRAINT FK_MeetingFoodReceipt_CheckIn FOREIGN KEY(ParticipantCheckInID) REFERENCES dbo.TDADMeetingParticipantCheckIn(ParticipantCheckInID),
  CONSTRAINT CK_MeetingFoodReceipt_Quantity CHECK(ReceivedQuantity BETWEEN 1 AND 99),
  CONSTRAINT CK_MeetingFoodReceipt_Method CHECK(ReceiptMethod IN ('SELF','DELEGATE'))
 );
 CREATE INDEX IX_MeetingFoodReceipt_Company ON dbo.TDADMeetingFoodReceipt(CompanyID,BookingFoodOrderDetailID);
 CREATE INDEX IX_MeetingFoodReceipt_CheckIn ON dbo.TDADMeetingFoodReceipt(ParticipantCheckInID);
END;

IF OBJECT_ID(N'dbo.TDADMeetingFoodReceiptHistory',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingFoodReceiptHistory
 (
  FoodReceiptHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingFoodReceiptHistory PRIMARY KEY,
  FoodReceiptID bigint NOT NULL,
  ParticipantCheckInID bigint NOT NULL,
  PreviousQuantity int NOT NULL,
  ReceivedQuantity int NOT NULL,
  ReceivedByUserID bigint NOT NULL,
  ReceivedAtUtc datetime2(7) NOT NULL,
  ReceiptMethod varchar(20) NOT NULL,
  CONSTRAINT FK_MeetingFoodReceiptHistory_Receipt FOREIGN KEY(FoodReceiptID) REFERENCES dbo.TDADMeetingFoodReceipt(FoodReceiptID),
  CONSTRAINT FK_MeetingFoodReceiptHistory_CheckIn FOREIGN KEY(ParticipantCheckInID) REFERENCES dbo.TDADMeetingParticipantCheckIn(ParticipantCheckInID),
  CONSTRAINT CK_MeetingFoodReceiptHistory_Quantity CHECK(PreviousQuantity>=0 AND ReceivedQuantity>PreviousQuantity AND ReceivedQuantity<=99),
  CONSTRAINT CK_MeetingFoodReceiptHistory_Method CHECK(ReceiptMethod IN ('SELF','DELEGATE'))
 );
 CREATE INDEX IX_MeetingFoodReceiptHistory_Receipt ON dbo.TDADMeetingFoodReceiptHistory(FoodReceiptID,FoodReceiptHistoryID);
END;
GO
-- Defense in depth for other writers: receipt ownership, check-in and quantity must agree.
CREATE OR ALTER TRIGGER dbo.TR_MeetingFoodReceipt_Validate ON dbo.TDADMeetingFoodReceipt
AFTER INSERT,UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(
  SELECT 1 FROM inserted R
  LEFT JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderDetailID=R.BookingFoodOrderDetailID
  LEFT JOIN dbo.TDADMeetingBookingFoodOrder H ON H.BookingFoodOrderID=D.BookingFoodOrderID AND H.CompanyID=R.CompanyID
  LEFT JOIN dbo.TDADMeetingParticipantCheckIn C ON C.ParticipantCheckInID=R.ParticipantCheckInID AND C.CompanyID=R.CompanyID AND C.BookingParticipantID=H.BookingParticipantID
  LEFT JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingSlotID=C.BookingSlotID AND S.CompanyID=H.CompanyID AND S.BookingID=H.BookingID
  LEFT JOIN dbo.TDADUser U ON U.UserID=R.ReceivedByUserID AND U.CompanyID=R.CompanyID AND U.IsActive=1
  WHERE H.BookingFoodOrderID IS NULL OR C.ParticipantCheckInID IS NULL OR S.BookingSlotID IS NULL
   OR U.UserID IS NULL OR R.ReceivedQuantity>D.Quantity
 ) THROW 51001, 'Receipt must match the company, checked-in participant and ordered quantity.', 1;
 IF EXISTS(SELECT 1 FROM inserted I JOIN deleted D ON D.FoodReceiptID=I.FoodReceiptID
  WHERE I.CompanyID<>D.CompanyID OR I.BookingFoodOrderDetailID<>D.BookingFoodOrderDetailID OR I.ReceivedQuantity<D.ReceivedQuantity)
  THROW 51002, 'An issued receipt cannot be reassigned or reduced.', 1;
END;
GO
-- Restrictive receipt FKs prevent delete/reinsert from erasing receipts. Also protect in-place edits.
CREATE OR ALTER TRIGGER dbo.TR_MeetingFoodOrderDetail_ProtectReceipt ON dbo.TDADMeetingBookingFoodOrderDetail
AFTER UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted I JOIN deleted D ON D.BookingFoodOrderDetailID=I.BookingFoodOrderDetailID
  JOIN dbo.TDADMeetingFoodReceipt R ON R.BookingFoodOrderDetailID=I.BookingFoodOrderDetailID
  WHERE I.Quantity<R.ReceivedQuantity OR I.FoodID<>D.FoodID OR I.BookingFoodOrderID<>D.BookingFoodOrderID)
  THROW 51003, 'A received food detail cannot be reassigned or reduced below its received quantity.', 1;
END;
GO
