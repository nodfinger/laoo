SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Booking core only. Future billing/document migrations remain separate.
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MARKET')
 THROW 59100,N'LAOO_MARKET bootstrap must run first.',1;
IF OBJECT_ID(N'dbo.TDMKSetting',N'U') IS NULL
 CREATE TABLE dbo.TDMKSetting(
  CompanyID bigint NOT NULL PRIMARY KEY,
  RequireDailyAgreement bit NOT NULL CONSTRAINT DF_TDMKSetting_Daily DEFAULT 0,
  AdvanceBookingDays int NOT NULL CONSTRAINT DF_TDMKSetting_Advance DEFAULT 90,
  UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKSetting_Update DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_TDMKSetting_Advance CHECK(AdvanceBookingDays BETWEEN 0 AND 365));
IF OBJECT_ID(N'dbo.TDMKMarket',N'U') IS NULL
 CREATE TABLE dbo.TDMKMarket(
  MarketID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  BranchID bigint NULL,MarketCode nvarchar(30) NOT NULL,MarketName nvarchar(150) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDMKMarket_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKMarket_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDMKMarket_Code UNIQUE(CompanyID,MarketCode));
IF OBJECT_ID(N'dbo.TDMKZone',N'U') IS NULL
 CREATE TABLE dbo.TDMKZone(
  ZoneID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  MarketID bigint NOT NULL,ZoneCode nvarchar(30) NOT NULL,ZoneName nvarchar(150) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDMKZone_Active DEFAULT 1,
  CONSTRAINT UQ_TDMKZone_Code UNIQUE(CompanyID,MarketID,ZoneCode));
IF OBJECT_ID(N'dbo.TDMKStall',N'U') IS NULL
 CREATE TABLE dbo.TDMKStall(
  StallID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  MarketID bigint NOT NULL,ZoneID bigint NOT NULL,StallCode nvarchar(30) NOT NULL,
  PosX int NOT NULL CONSTRAINT DF_TDMKStall_X DEFAULT 0,
  PosY int NOT NULL CONSTRAINT DF_TDMKStall_Y DEFAULT 0,
  WidthUnits int NOT NULL CONSTRAINT DF_TDMKStall_Width DEFAULT 1,
  HeightUnits int NOT NULL CONSTRAINT DF_TDMKStall_Height DEFAULT 1,
  IsActive bit NOT NULL CONSTRAINT DF_TDMKStall_Active DEFAULT 1,
  CONSTRAINT UQ_TDMKStall_Code UNIQUE(CompanyID,MarketID,StallCode),
  CONSTRAINT CK_TDMKStall_Size CHECK(WidthUnits>0 AND HeightUnits>0));
IF OBJECT_ID(N'dbo.TDMKTrader',N'U') IS NULL
 CREATE TABLE dbo.TDMKTrader(
  TraderID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  CustomerID bigint NULL,TraderName nvarchar(200) NOT NULL,Phone nvarchar(50) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDMKTrader_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKTrader_Create DEFAULT SYSUTCDATETIME());
IF OBJECT_ID(N'dbo.TDMKInquiry',N'U') IS NULL
 CREATE TABLE dbo.TDMKInquiry(
  InquiryID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  MarketID bigint NOT NULL,ContactName nvarchar(200) NOT NULL,Phone nvarchar(50) NOT NULL,
  Requirement nvarchar(2000) NULL,StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDMKInquiry_Status DEFAULT N'OPEN',
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKInquiry_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_TDMKInquiry_Status CHECK(StatusCode IN(N'OPEN',N'FOLLOW_UP',N'CLOSED')));
IF OBJECT_ID(N'dbo.TDMKContract',N'U') IS NULL
 CREATE TABLE dbo.TDMKContract(
  ContractID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  StallID bigint NOT NULL,TraderID bigint NOT NULL,StartsOn date NOT NULL,EndsOn date NOT NULL,
  RentCycleCode nvarchar(10) NOT NULL,StatusCode nvarchar(20) NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKContract_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_TDMKContract_Dates CHECK(EndsOn>=StartsOn),
  CONSTRAINT CK_TDMKContract_Cycle CHECK(RentCycleCode IN(N'DAILY',N'MONTHLY')),
  CONSTRAINT CK_TDMKContract_Status CHECK(StatusCode IN(N'DRAFT',N'ACTIVE',N'ENDED',N'CANCELLED')));
IF OBJECT_ID(N'dbo.TDMKStallStatusPeriod',N'U') IS NULL
 CREATE TABLE dbo.TDMKStallStatusPeriod(
  PeriodID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  StallID bigint NOT NULL,StatusCode nvarchar(20) NOT NULL,
  StartsOn date NOT NULL,EndsOn date NULL,Reason nvarchar(500) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDMKPeriod_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKPeriod_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_TDMKPeriod_Status CHECK(StatusCode IN(N'CLOSED',N'RENOVATION')),
  CONSTRAINT CK_TDMKPeriod_Dates CHECK(EndsOn IS NULL OR EndsOn>=StartsOn),
  CONSTRAINT CK_TDMKPeriod_Renovation CHECK(StatusCode<>N'RENOVATION' OR EndsOn IS NOT NULL));
IF OBJECT_ID(N'dbo.TDMKBooking',N'U') IS NULL
 CREATE TABLE dbo.TDMKBooking(
  BookingID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  StallID bigint NOT NULL,TraderID bigint NOT NULL,StartsOn date NOT NULL,EndsOn date NOT NULL,
  ExpiresAt datetime2(3) NOT NULL,StatusCode nvarchar(20) NOT NULL,
  IdempotencyKey uniqueidentifier NOT NULL,CreatedBy bigint NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKBooking_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDMKBooking_Key UNIQUE(CompanyID,IdempotencyKey),
  CONSTRAINT CK_TDMKBooking_Dates CHECK(EndsOn>=StartsOn),
  CONSTRAINT CK_TDMKBooking_Status CHECK(StatusCode IN(N'RESERVED',N'EXPIRED',N'CANCELLED',N'CONVERTED')));
IF OBJECT_ID(N'dbo.TDMKAudit',N'U') IS NULL
 CREATE TABLE dbo.TDMKAudit(
  AuditID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL,
  ActorUserID bigint NOT NULL,ActionCode nvarchar(40) NOT NULL,
  EntityType nvarchar(40) NOT NULL,EntityID bigint NOT NULL,
  Remark nvarchar(1000) NULL,CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDMKAudit_Create DEFAULT SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDMKBooking') AND name=N'IX_TDMKBooking_StallDates')
 CREATE INDEX IX_TDMKBooking_StallDates ON dbo.TDMKBooking(CompanyID,StallID,StartsOn,EndsOn,StatusCode);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDMKContract') AND name=N'IX_TDMKContract_StallDates')
 CREATE INDEX IX_TDMKContract_StallDates ON dbo.TDMKContract(CompanyID,StallID,StartsOn,EndsOn,StatusCode);
