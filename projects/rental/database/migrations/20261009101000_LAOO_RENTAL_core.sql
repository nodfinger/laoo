SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Rental-owned schema. Run only after approval through run-migrations.ps1.
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_RENTAL')
 THROW 60010,N'Run rental bootstrap first.',1;
IF OBJECT_ID(N'dbo.TDRNSetting',N'U') IS NULL
 CREATE TABLE dbo.TDRNSetting(
  CompanyID bigint NOT NULL CONSTRAINT PK_TDRNSetting PRIMARY KEY,
  BookingHoldHours int NOT NULL CONSTRAINT DF_TDRNSetting_Hold DEFAULT 24,
  CancelBeforeHours int NOT NULL CONSTRAINT DF_TDRNSetting_Cancel DEFAULT 2,
  UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNSetting_Updated DEFAULT SYSUTCDATETIME(),
  UpdatedBy bigint NULL,
  CONSTRAINT CK_TDRNSetting_Hold CHECK(BookingHoldHours BETWEEN 1 AND 168),
  CONSTRAINT CK_TDRNSetting_Cancel CHECK(CancelBeforeHours BETWEEN 0 AND 168));
IF OBJECT_ID(N'dbo.TDRNItem',N'U') IS NULL
 CREATE TABLE dbo.TDRNItem(
  RentalItemID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNItem PRIMARY KEY,
  CompanyID bigint NOT NULL,BranchID bigint NOT NULL,ItemID bigint NOT NULL,
  WarehouseID bigint NOT NULL,RateUnit nvarchar(10) NOT NULL,
  RentalRate decimal(18,2) NOT NULL,DepositAmount decimal(18,2) NOT NULL,
  RequireSerial bit NOT NULL CONSTRAINT DF_TDRNItem_Serial DEFAULT 0,
  IsActive bit NOT NULL CONSTRAINT DF_TDRNItem_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNItem_Created DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,UpdatedAt datetime2(3) NULL,UpdatedBy bigint NULL,
  CONSTRAINT UQ_TDRNItem_Company_Branch_Item UNIQUE(CompanyID,BranchID,ItemID),
  CONSTRAINT UQ_TDRNItem_Company_ID UNIQUE(CompanyID,RentalItemID),
  CONSTRAINT CK_TDRNItem_Unit CHECK(RateUnit IN(N'HOUR',N'DAY')),
  CONSTRAINT CK_TDRNItem_Amounts CHECK(RentalRate>=0 AND DepositAmount>=0));
IF OBJECT_ID(N'dbo.TDRNBooking',N'U') IS NULL
 CREATE TABLE dbo.TDRNBooking(
  BookingID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNBooking PRIMARY KEY,
  CompanyID bigint NOT NULL,BranchID bigint NOT NULL,CustomerID bigint NOT NULL,
  BookingCode nvarchar(40) NULL,StartAt datetime2(3) NOT NULL,EndAt datetime2(3) NOT NULL,
  ExpiresAt datetime2(3) NOT NULL,StatusCode nvarchar(30) NOT NULL,
  TotalRent decimal(18,2) NOT NULL,TotalDeposit decimal(18,2) NOT NULL,
  IdempotencyKey nvarchar(100) NOT NULL,RequestHash char(64) NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNBooking_Created DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,UpdatedAt datetime2(3) NULL,
  CancelReason nvarchar(1000) NULL,CancelledAt datetime2(3) NULL,CancelledBy bigint NULL,
  CONSTRAINT UQ_TDRNBooking_Company_ID UNIQUE(CompanyID,BookingID),
  CONSTRAINT UQ_TDRNBooking_Idempotency UNIQUE(CompanyID,IdempotencyKey),
  CONSTRAINT CK_TDRNBooking_Period CHECK(EndAt>StartAt),
  CONSTRAINT CK_TDRNBooking_Amounts CHECK(TotalRent>=0 AND TotalDeposit>=0),
  CONSTRAINT CK_TDRNBooking_Status CHECK(StatusCode IN(N'RESERVED',N'PAID',N'OUT',
   N'PARTIAL_RETURN',N'RETURNED',N'SETTLEMENT',N'CLOSED',N'CANCELLED')));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDRNBooking')
 AND name=N'UX_TDRNBooking_Company_Code')
 CREATE UNIQUE INDEX UX_TDRNBooking_Company_Code ON dbo.TDRNBooking(CompanyID,BookingCode)
 WHERE BookingCode IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDRNBooking')
 AND name=N'IX_TDRNBooking_Availability')
 CREATE INDEX IX_TDRNBooking_Availability
 ON dbo.TDRNBooking(CompanyID,BranchID,StatusCode,StartAt,EndAt);
IF OBJECT_ID(N'dbo.TDRNBookingLine',N'U') IS NULL
 CREATE TABLE dbo.TDRNBookingLine(
  BookingLineID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNBookingLine PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NOT NULL,RentalItemID bigint NOT NULL,
  ItemID bigint NOT NULL,WarehouseID bigint NOT NULL,Quantity int NOT NULL,
  RateUnitSnapshot nvarchar(10) NOT NULL,RateSnapshot decimal(18,2) NOT NULL,
  RequireSerialSnapshot bit NOT NULL,RentAmount decimal(18,2) NOT NULL,
  DepositAmount decimal(18,2) NOT NULL,
  CONSTRAINT UQ_TDRNBookingLine_Company_ID UNIQUE(CompanyID,BookingLineID),
  CONSTRAINT UQ_TDRNBookingLine_Item UNIQUE(CompanyID,BookingID,RentalItemID),
  CONSTRAINT FK_TDRNBookingLine_Booking FOREIGN KEY(CompanyID,BookingID)
   REFERENCES dbo.TDRNBooking(CompanyID,BookingID),
  CONSTRAINT FK_TDRNBookingLine_Item FOREIGN KEY(CompanyID,RentalItemID)
   REFERENCES dbo.TDRNItem(CompanyID,RentalItemID),
  CONSTRAINT CK_TDRNBookingLine_Qty CHECK(Quantity>0),
  CONSTRAINT CK_TDRNBookingLine_Amounts CHECK(RateSnapshot>=0 AND RentAmount>=0 AND DepositAmount>=0));
IF OBJECT_ID(N'dbo.TDRNPaymentLedger',N'U') IS NULL
 CREATE TABLE dbo.TDRNPaymentLedger(
  PaymentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDRNPaymentLedger PRIMARY KEY,
  CompanyID bigint NOT NULL,BookingID bigint NOT NULL,
  Kind nvarchar(30) NOT NULL,Amount decimal(18,2) NOT NULL,
  Method nvarchar(20) NOT NULL,ReferenceNo nvarchar(100) NULL,
  IdempotencyKey nvarchar(100) NOT NULL,RequestHash char(64) NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDRNPayment_Created DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,
  CONSTRAINT UQ_TDRNPayment_Key UNIQUE(CompanyID,IdempotencyKey),
  CONSTRAINT FK_TDRNPayment_Booking FOREIGN KEY(CompanyID,BookingID)
   REFERENCES dbo.TDRNBooking(CompanyID,BookingID),
  CONSTRAINT CK_TDRNPayment_Kind CHECK(Kind IN(N'RENT',N'DEPOSIT',N'ADDITIONAL',
   N'RENT_REFUND',N'DEPOSIT_REFUND')),
  CONSTRAINT CK_TDRNPayment_Amount CHECK(Amount>0),
  CONSTRAINT CK_TDRNPayment_Method CHECK(Method IN(N'CASH',N'TRANSFER')));
