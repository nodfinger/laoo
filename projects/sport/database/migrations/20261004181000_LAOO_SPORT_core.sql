SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Sport business schema. Must be run by tools/scripts/run-migrations.ps1 after approval.
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SPORT')
 THROW 57411,N'LAOO_SPORT bootstrap is required.',1;
IF OBJECT_ID(N'dbo.TDSPSetting',N'U') IS NULL
 CREATE TABLE dbo.TDSPSetting(
  CompanyID bigint NOT NULL PRIMARY KEY,ProjectID bigint NOT NULL,
  PaymentHoldMinutes int NOT NULL CONSTRAINT DF_TDSPSetting_Hold DEFAULT 30,
  CancelBeforeMinutes int NOT NULL CONSTRAINT DF_TDSPSetting_Cancel DEFAULT 120,
  CheckInGraceMinutes int NOT NULL CONSTRAINT DF_TDSPSetting_Grace DEFAULT 15,
  ExpiryNoticeDays int NOT NULL CONSTRAINT DF_TDSPSetting_Notice DEFAULT 30,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPSetting_Create DEFAULT SYSUTCDATETIME(),
  UpdatedAt datetime2(3) NULL,
  CONSTRAINT CK_TDSPSetting_Positive CHECK(PaymentHoldMinutes BETWEEN 1 AND 1440 AND CancelBeforeMinutes BETWEEN 0 AND 10080 AND CheckInGraceMinutes BETWEEN 0 AND 1440 AND ExpiryNoticeDays BETWEEN 1 AND 365));
IF OBJECT_ID(N'dbo.TDSPSportType',N'U') IS NULL
 CREATE TABLE dbo.TDSPSportType(
  SportTypeID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  SportCode nvarchar(30) NOT NULL,SportName nvarchar(150) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPSportType_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPSportType_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDSPSportType_Code UNIQUE(CompanyID,SportCode));
IF OBJECT_ID(N'dbo.TDSPFacility',N'U') IS NULL
 CREATE TABLE dbo.TDSPFacility(
  FacilityID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,BranchID bigint NOT NULL,
  SportTypeID bigint NOT NULL,FacilityCode nvarchar(30) NOT NULL,FacilityName nvarchar(150) NOT NULL,
  Capacity int NOT NULL CONSTRAINT DF_TDSPFacility_Capacity DEFAULT 1,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPFacility_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPFacility_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDSPFacility_Code UNIQUE(CompanyID,FacilityCode),
  CONSTRAINT CK_TDSPFacility_Capacity CHECK(Capacity>0));
IF OBJECT_ID(N'dbo.TDSPFacilityHours',N'U') IS NULL
 CREATE TABLE dbo.TDSPFacilityHours(
  HoursID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,FacilityID bigint NOT NULL,
  DayOfWeek tinyint NOT NULL,OpensAt time(0) NOT NULL,ClosesAt time(0) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPFacilityHours_Active DEFAULT 1,
  CONSTRAINT CK_TDSPFacilityHours_Day CHECK(DayOfWeek BETWEEN 0 AND 6),
  CONSTRAINT CK_TDSPFacilityHours_Time CHECK(OpensAt<ClosesAt));
IF OBJECT_ID(N'dbo.TDSPFacilityBlock',N'U') IS NULL
 CREATE TABLE dbo.TDSPFacilityBlock(
  BlockID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,FacilityID bigint NOT NULL,
  StartsAt datetime2(3) NOT NULL,EndsAt datetime2(3) NOT NULL,Reason nvarchar(300) NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPFacilityBlock_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_TDSPFacilityBlock_Time CHECK(StartsAt<EndsAt));
IF OBJECT_ID(N'dbo.TDSPMemberLevel',N'U') IS NULL
 CREATE TABLE dbo.TDSPMemberLevel(
  LevelID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  LevelCode nvarchar(30) NOT NULL,LevelName nvarchar(150) NOT NULL,
  RequiresResident bit NOT NULL CONSTRAINT DF_TDSPMemberLevel_Resident DEFAULT 0,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPMemberLevel_Active DEFAULT 1,
  CONSTRAINT UQ_TDSPMemberLevel_Code UNIQUE(CompanyID,LevelCode));
IF OBJECT_ID(N'dbo.TDSPMember',N'U') IS NULL
 CREATE TABLE dbo.TDSPMember(
  MemberID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  PersonID bigint NOT NULL,MemberCode nvarchar(30) NOT NULL,LevelID bigint NOT NULL,
  BirthDate date NULL,GenderCode nvarchar(20) NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPMember_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPMember_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDSPMember_Code UNIQUE(CompanyID,MemberCode),
  CONSTRAINT UQ_TDSPMember_Person UNIQUE(CompanyID,PersonID),
  CONSTRAINT CK_TDSPMember_Gender CHECK(GenderCode IS NULL OR GenderCode IN(N'MALE',N'FEMALE',N'OTHER',N'UNSPECIFIED')));
IF OBJECT_ID(N'dbo.TDSPMemberCredential',N'U') IS NULL
 CREATE TABLE dbo.TDSPMemberCredential(
  CompanyID bigint NOT NULL,MemberID bigint NOT NULL,PasswordHash nvarchar(500) NOT NULL,
  FailedLoginCount int NOT NULL CONSTRAINT DF_TDSPCredential_Failed DEFAULT 0,
  LockedUntil datetime2(3) NULL,TokenVersion int NOT NULL CONSTRAINT DF_TDSPCredential_Version DEFAULT 1,
  MustChangePassword bit NOT NULL CONSTRAINT DF_TDSPCredential_Change DEFAULT 1,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPCredential_Active DEFAULT 1,
  UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPCredential_Update DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_TDSPMemberCredential PRIMARY KEY(CompanyID,MemberID));
IF OBJECT_ID(N'dbo.TDSPPackage',N'U') IS NULL
 CREATE TABLE dbo.TDSPPackage(
  PackageID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  PackageCode nvarchar(30) NOT NULL,PackageName nvarchar(150) NOT NULL,
  LevelID bigint NULL,DurationDays int NOT NULL,QuotaUnit nvarchar(10) NOT NULL,
  QuotaAmount decimal(12,2) NULL,Price decimal(18,2) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPPackage_Active DEFAULT 1,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPPackage_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDSPPackage_Code UNIQUE(CompanyID,PackageCode),
  CONSTRAINT CK_TDSPPackage_Values CHECK(DurationDays>0 AND Price>=0 AND QuotaUnit IN(N'VISIT',N'HOUR',N'UNLIMITED') AND ((QuotaUnit=N'UNLIMITED' AND QuotaAmount IS NULL) OR (QuotaUnit<>N'UNLIMITED' AND QuotaAmount>0))));
IF OBJECT_ID(N'dbo.TDSPPackageSport',N'U') IS NULL
 CREATE TABLE dbo.TDSPPackageSport(
  CompanyID bigint NOT NULL,PackageID bigint NOT NULL,SportTypeID bigint NOT NULL,
  CONSTRAINT PK_TDSPPackageSport PRIMARY KEY(CompanyID,PackageID,SportTypeID));
IF OBJECT_ID(N'dbo.TDSPMembership',N'U') IS NULL
 CREATE TABLE dbo.TDSPMembership(
  MembershipID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  MemberID bigint NOT NULL,PackageID bigint NOT NULL,
  StartsOn date NOT NULL,EndsOn date NOT NULL,
  PackageNameSnapshot nvarchar(150) NOT NULL,
  SportCodesSnapshot nvarchar(1000) NOT NULL,
  PriceSnapshot decimal(18,2) NOT NULL,
  QuotaUnitSnapshot nvarchar(10) NOT NULL,
  QuotaAmountSnapshot decimal(12,2) NULL,
  StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSPMembership_Status DEFAULT N'ACTIVE',
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPMembership_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_TDSPMembership_Dates CHECK(StartsOn<=EndsOn),
  CONSTRAINT CK_TDSPMembership_Price CHECK(PriceSnapshot>=0),
  CONSTRAINT CK_TDSPMembership_Status CHECK(StatusCode IN(N'ACTIVE',N'EXPIRED',N'CANCELLED')));
IF OBJECT_ID(N'dbo.TDSPBooking',N'U') IS NULL
 CREATE TABLE dbo.TDSPBooking(
  BookingID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  BranchID bigint NOT NULL,FacilityID bigint NOT NULL,MemberID bigint NOT NULL,
  MembershipID bigint NULL,StartsAt datetime2(3) NOT NULL,EndsAt datetime2(3) NOT NULL,
  StatusCode nvarchar(25) NOT NULL,PaymentDueAt datetime2(3) NULL,
  PriceSnapshot decimal(18,2) NOT NULL,
  IdempotencyKey uniqueidentifier NOT NULL,
  CheckedInAt datetime2(3) NULL,CheckedInBy bigint NULL,
  CancelledAt datetime2(3) NULL,CancelReason nvarchar(500) NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPBooking_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDSPBooking_Key UNIQUE(CompanyID,IdempotencyKey),
  CONSTRAINT CK_TDSPBooking_Time CHECK(StartsAt<EndsAt),
  CONSTRAINT CK_TDSPBooking_Price CHECK(PriceSnapshot>=0),
  CONSTRAINT CK_TDSPBooking_Status CHECK(StatusCode IN(N'PENDING_PAYMENT',N'CONFIRMED',N'CHECKED_IN',N'NO_SHOW',N'CANCELLED',N'EXPIRED')));
IF OBJECT_ID(N'dbo.TDSPMembershipUse',N'U') IS NULL
 CREATE TABLE dbo.TDSPMembershipUse(
  UseID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  MembershipID bigint NOT NULL,BookingID bigint NOT NULL,
  Units decimal(12,2) NOT NULL,StatusCode nvarchar(15) NOT NULL,
  ReservedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPUse_Reserve DEFAULT SYSUTCDATETIME(),
  FinalizedAt datetime2(3) NULL,
  CONSTRAINT UQ_TDSPUse_Booking UNIQUE(CompanyID,BookingID),
  CONSTRAINT CK_TDSPUse_Units CHECK(Units>0),
  CONSTRAINT CK_TDSPUse_Status CHECK(StatusCode IN(N'RESERVED',N'CONSUMED',N'RELEASED')));
IF OBJECT_ID(N'dbo.TDSPPayment',N'U') IS NULL
 CREATE TABLE dbo.TDSPPayment(
  PaymentID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  MembershipID bigint NULL,BookingID bigint NULL,
  Amount decimal(18,2) NOT NULL,PaymentCode nvarchar(20) NOT NULL,
  PaymentReference nvarchar(100) NULL,StatusCode nvarchar(15) NOT NULL,
  IdempotencyKey uniqueidentifier NOT NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPPayment_Create DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NOT NULL,VoidedAt datetime2(3) NULL,VoidReason nvarchar(500) NULL,
  CONSTRAINT UQ_TDSPPayment_Key UNIQUE(CompanyID,IdempotencyKey),
  CONSTRAINT CK_TDSPPayment_Target CHECK((MembershipID IS NULL AND BookingID IS NOT NULL) OR (MembershipID IS NOT NULL AND BookingID IS NULL)),
  CONSTRAINT CK_TDSPPayment_Amount CHECK(Amount>0),
  CONSTRAINT CK_TDSPPayment_Code CHECK(PaymentCode IN(N'CASH',N'TRANSFER')),
  CONSTRAINT CK_TDSPPayment_Status CHECK(StatusCode IN(N'RECORDED',N'VOIDED')));
IF OBJECT_ID(N'dbo.TDSPPosPriceRule',N'U') IS NULL
 CREATE TABLE dbo.TDSPPosPriceRule(
  CompanyID bigint NOT NULL,LevelID bigint NOT NULL,
  PriceLevelCode nvarchar(30) NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSPPosPrice_Active DEFAULT 1,
  UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPPosPrice_Update DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_TDSPPosPriceRule PRIMARY KEY(CompanyID,LevelID));
IF OBJECT_ID(N'dbo.TDSPAudit',N'U') IS NULL
 CREATE TABLE dbo.TDSPAudit(
  AuditID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,
  ActorUserID bigint NULL,ActorMemberID bigint NULL,
  ActionCode nvarchar(40) NOT NULL,EntityType nvarchar(40) NOT NULL,
  EntityID bigint NOT NULL,Detail nvarchar(1000) NULL,
  CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDSPAudit_Create DEFAULT SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDSPBooking') AND name=N'IX_TDSPBooking_Facility_Time')
 CREATE INDEX IX_TDSPBooking_Facility_Time ON dbo.TDSPBooking(CompanyID,FacilityID,StartsAt,EndsAt) INCLUDE(StatusCode,PaymentDueAt);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDSPMembership') AND name=N'IX_TDSPMembership_Member_Expiry')
 CREATE INDEX IX_TDSPMembership_Member_Expiry ON dbo.TDSPMembership(CompanyID,MemberID,EndsOn) INCLUDE(StatusCode,QuotaUnitSnapshot,QuotaAmountSnapshot);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDSPMember') AND name=N'IX_TDSPMember_Level_Demographic')
 CREATE INDEX IX_TDSPMember_Level_Demographic ON dbo.TDSPMember(CompanyID,LevelID,GenderCode,BirthDate) INCLUDE(IsActive);
