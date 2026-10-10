SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Private-file metadata, handover, return and settlement. Approval required before execution.
IF OBJECT_ID(N'dbo.TDRNBookingLine',N'U') IS NULL
 THROW 60020,N'Run rental core migration first.',1;
IF OBJECT_ID(N'dbo.TDRNAttachment',N'U') IS NULL
 CREATE TABLE dbo.TDRNAttachment(
  AttachmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNAttachment PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NOT NULL,BookingLineID bigint NULL,
  ReturnID bigint NULL,
  Kind nvarchar(30) NOT NULL,StoredName nvarchar(100) NOT NULL,
  OriginalName nvarchar(260) NOT NULL,MimeType nvarchar(100) NOT NULL,
  SizeBytes bigint NOT NULL,Sha256 char(64) NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNAttachment_Created DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,
  CONSTRAINT FK_TDRNAttachment_Booking FOREIGN KEY(CompanyID,BookingID)
   REFERENCES dbo.TDRNBooking(CompanyID,BookingID),
  CONSTRAINT FK_TDRNAttachment_Line FOREIGN KEY(CompanyID,BookingLineID)
   REFERENCES dbo.TDRNBookingLine(CompanyID,BookingLineID),
  CONSTRAINT CK_TDRNAttachment_Kind CHECK(Kind IN(
   N'HANDOVER_PHOTO',N'HANDOVER_STAFF_SIGN',N'HANDOVER_CUSTOMER_SIGN',
   N'RETURN_PHOTO',N'RETURN_STAFF_SIGN',N'RETURN_CUSTOMER_SIGN')),
  CONSTRAINT CK_TDRNAttachment_Size CHECK(SizeBytes BETWEEN 1 AND 10000000),
  CONSTRAINT UQ_TDRNAttachment_Stored UNIQUE(CompanyID,BookingID,StoredName));
IF OBJECT_ID(N'dbo.TDRNHandover',N'U') IS NULL
 CREATE TABLE dbo.TDRNHandover(
  HandoverID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNHandover PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NOT NULL,
  StaffSignAttachmentID bigint NOT NULL,CustomerSignAttachmentID bigint NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNHandover_Created DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,
  CONSTRAINT UQ_TDRNHandover_Booking UNIQUE(CompanyID,BookingID),
  CONSTRAINT FK_TDRNHandover_Booking FOREIGN KEY(CompanyID,BookingID)
   REFERENCES dbo.TDRNBooking(CompanyID,BookingID));
IF OBJECT_ID(N'dbo.TDRNReturn',N'U') IS NULL
 CREATE TABLE dbo.TDRNReturn(
  ReturnID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNReturn PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NOT NULL,
  StaffSignAttachmentID bigint NOT NULL,CustomerSignAttachmentID bigint NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNReturn_Created DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,
  CONSTRAINT UQ_TDRNReturn_Company_ID UNIQUE(CompanyID,ReturnID),
  CONSTRAINT FK_TDRNReturn_Booking FOREIGN KEY(CompanyID,BookingID)
   REFERENCES dbo.TDRNBooking(CompanyID,BookingID));
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_TDRNAttachment_Return')
 ALTER TABLE dbo.TDRNAttachment ADD CONSTRAINT FK_TDRNAttachment_Return
 FOREIGN KEY(CompanyID,ReturnID) REFERENCES dbo.TDRNReturn(CompanyID,ReturnID);
IF OBJECT_ID(N'dbo.TDRNSerialAssignment',N'U') IS NULL
 CREATE TABLE dbo.TDRNSerialAssignment(
  SerialAssignmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNSerial PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NOT NULL,BookingLineID bigint NOT NULL,
  ItemInstanceID bigint NOT NULL,ReturnID bigint NULL,ReturnedAt datetime2(3) NULL,
  CONSTRAINT UQ_TDRNSerial_Line_Instance UNIQUE(CompanyID,BookingLineID,ItemInstanceID),
  CONSTRAINT FK_TDRNSerial_Booking FOREIGN KEY(CompanyID,BookingID)
   REFERENCES dbo.TDRNBooking(CompanyID,BookingID),
  CONSTRAINT FK_TDRNSerial_Line FOREIGN KEY(CompanyID,BookingLineID)
   REFERENCES dbo.TDRNBookingLine(CompanyID,BookingLineID),
  CONSTRAINT FK_TDRNSerial_Return FOREIGN KEY(CompanyID,ReturnID)
   REFERENCES dbo.TDRNReturn(CompanyID,ReturnID));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDRNSerialAssignment')
 AND name=N'UX_TDRNSerial_Active')
 CREATE UNIQUE INDEX UX_TDRNSerial_Active
 ON dbo.TDRNSerialAssignment(CompanyID,ItemInstanceID) WHERE ReturnID IS NULL;
IF OBJECT_ID(N'dbo.TDRNReturnLine',N'U') IS NULL
 CREATE TABLE dbo.TDRNReturnLine(
  ReturnLineID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNReturnLine PRIMARY KEY,
  CompanyID bigint NOT NULL,ReturnID bigint NOT NULL,BookingLineID bigint NOT NULL,
  Quantity int NOT NULL,ConditionCode nvarchar(20) NOT NULL,
  DamageAmount decimal(18,2) NOT NULL,LateFee decimal(18,2) NOT NULL,
  Remark nvarchar(1000) NULL,
  CONSTRAINT FK_TDRNReturnLine_Return FOREIGN KEY(CompanyID,ReturnID)
   REFERENCES dbo.TDRNReturn(CompanyID,ReturnID),
  CONSTRAINT FK_TDRNReturnLine_Line FOREIGN KEY(CompanyID,BookingLineID)
   REFERENCES dbo.TDRNBookingLine(CompanyID,BookingLineID),
  CONSTRAINT CK_TDRNReturnLine_Qty CHECK(Quantity>0),
  CONSTRAINT CK_TDRNReturnLine_Condition CHECK(ConditionCode IN(N'OK',N'DAMAGED',N'LOST')),
  CONSTRAINT CK_TDRNReturnLine_Amount CHECK(DamageAmount>=0 AND LateFee>=0));
IF OBJECT_ID(N'dbo.TDRNSettlement',N'U') IS NULL
 CREATE TABLE dbo.TDRNSettlement(
  SettlementID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNSettlement PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NOT NULL,
  ProposedDamage decimal(18,2) NOT NULL,ProposedLate decimal(18,2) NOT NULL,
  ApprovedDeduction decimal(18,2) NOT NULL,RefundDue decimal(18,2) NOT NULL,
  AdditionalDue decimal(18,2) NOT NULL,Reason nvarchar(1000) NOT NULL,
  StatusCode nvarchar(20) NOT NULL,ApprovedAt datetime2(3) NOT NULL
   CONSTRAINT DF_TDRNSettlement_Approved DEFAULT SYSUTCDATETIME(),
  ApprovedBy bigint NOT NULL,RefundedAt datetime2(3) NULL,RefundedBy bigint NULL,
  CONSTRAINT UQ_TDRNSettlement_Booking UNIQUE(CompanyID,BookingID),
  CONSTRAINT FK_TDRNSettlement_Booking FOREIGN KEY(CompanyID,BookingID)
   REFERENCES dbo.TDRNBooking(CompanyID,BookingID),
  CONSTRAINT CK_TDRNSettlement_Status CHECK(StatusCode IN(N'APPROVED',N'REFUNDED')),
  CONSTRAINT CK_TDRNSettlement_Amounts CHECK(ProposedDamage>=0 AND ProposedLate>=0
   AND ApprovedDeduction>=0 AND RefundDue>=0 AND AdditionalDue>=0));
IF OBJECT_ID(N'dbo.TDRNStockTransfer',N'U') IS NULL
 CREATE TABLE dbo.TDRNStockTransfer(
  TransferID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNStockTransfer PRIMARY KEY,
  CompanyID bigint NOT NULL,RentalItemID bigint NOT NULL,
  SourceWarehouseID bigint NOT NULL,TargetWarehouseID bigint NOT NULL,
  DirectionCode nvarchar(20) NOT NULL,Quantity int NOT NULL,
  IdempotencyKey nvarchar(100) NOT NULL,RequestHash char(64) NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNStockTransfer_Created DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,
  CONSTRAINT FK_TDRNStockTransfer_Item FOREIGN KEY(CompanyID,RentalItemID)
   REFERENCES dbo.TDRNItem(CompanyID,RentalItemID),
  CONSTRAINT UQ_TDRNStockTransfer_Key UNIQUE(CompanyID,IdempotencyKey),
  CONSTRAINT CK_TDRNStockTransfer_Direction CHECK(DirectionCode IN(N'TO_RENTAL',N'FROM_RENTAL')),
  CONSTRAINT CK_TDRNStockTransfer_Qty CHECK(Quantity>0),
  CONSTRAINT CK_TDRNStockTransfer_Different CHECK(SourceWarehouseID<>TargetWarehouseID));
IF OBJECT_ID(N'dbo.TDRNAudit',N'U') IS NULL
 CREATE TABLE dbo.TDRNAudit(
  AuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNAudit PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NULL,RentalItemID bigint NULL,
  EventCode nvarchar(50) NOT NULL,Detail nvarchar(1000) NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNAudit_Created DEFAULT SYSUTCDATETIME(),
  ActorID bigint NOT NULL);
