SET NOCOUNT ON;
SET XACT_ABORT ON;
CREATE TABLE dbo.TDPTSetting(
 CompanyID bigint NOT NULL PRIMARY KEY, ReminderHours int NOT NULL DEFAULT 24,
 CheckInStart time NOT NULL DEFAULT '09:00', CheckInEnd time NOT NULL DEFAULT '18:00',
 UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_TDPTSetting_Reminder CHECK(ReminderHours BETWEEN 0 AND 720));
CREATE TABLE dbo.TDPTServiceMap(
 CompanyID bigint NOT NULL, ServiceID bigint NOT NULL, KindCode nvarchar(30) NOT NULL,
 UnitCode nvarchar(20) NOT NULL, IsActive bit NOT NULL DEFAULT 1,
 CONSTRAINT PK_TDPTServiceMap PRIMARY KEY(CompanyID,ServiceID),
 CONSTRAINT FK_TDPTServiceMap_BookingService FOREIGN KEY(CompanyID,ServiceID) REFERENCES dbo.TDBKService(CompanyID,ServiceID),
 CONSTRAINT CK_TDPTServiceMap_Kind CHECK(KindCode IN(N'HOTEL',N'GROOMING',N'DAYCARE',N'TRANSPORT')));
CREATE TABLE dbo.TDPTRoom(
 CompanyID bigint NOT NULL, RoomID bigint IDENTITY NOT NULL, ResourceID bigint NOT NULL,
 RoomCode nvarchar(30) NOT NULL, RoomName nvarchar(150) NOT NULL,
 Capacity int NOT NULL DEFAULT 1, IsActive bit NOT NULL DEFAULT 1,
 CONSTRAINT PK_TDPTRoom PRIMARY KEY(CompanyID,RoomID),
 CONSTRAINT UQ_TDPTRoom_Code UNIQUE(CompanyID,RoomCode),
 CONSTRAINT UQ_TDPTRoom_Resource UNIQUE(CompanyID,ResourceID),
 CONSTRAINT FK_TDPTRoom_Resource FOREIGN KEY(CompanyID,ResourceID) REFERENCES dbo.TDBKResource(CompanyID,ResourceID),
 CONSTRAINT CK_TDPTRoom_Capacity CHECK(Capacity>0));
CREATE TABLE dbo.TDPTPet(
 CompanyID bigint NOT NULL, PetID bigint IDENTITY NOT NULL, PetCode nvarchar(30) NOT NULL,
 OwnerCustomerID bigint NOT NULL, MemberID bigint NULL, PetName nvarchar(150) NOT NULL,
 Species nvarchar(80) NOT NULL, Breed nvarchar(100) NULL, SizeCode nvarchar(20) NULL,
 BirthDate date NULL, CautionText nvarchar(2000) NULL,
 EmergencyName nvarchar(150) NULL, EmergencyPhone nvarchar(50) NULL,
 IsActive bit NOT NULL DEFAULT 1, CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_TDPTPet PRIMARY KEY(CompanyID,PetID),
 CONSTRAINT UQ_TDPTPet_Code UNIQUE(CompanyID,PetCode),
 CONSTRAINT FK_TDPTPet_Member FOREIGN KEY(CompanyID,MemberID) REFERENCES dbo.TDBKMember(CompanyID,MemberID));
CREATE INDEX IX_TDPTPet_Owner ON dbo.TDPTPet(CompanyID,OwnerCustomerID,IsActive);
CREATE TABLE dbo.TDPTStay(
 CompanyID bigint NOT NULL, StayID bigint IDENTITY NOT NULL, BookingID bigint NOT NULL,
 PetID bigint NOT NULL, RoomID bigint NULL, StartsAt datetime2 NOT NULL, EndsAt datetime2 NOT NULL,
 StatusCode nvarchar(20) NOT NULL DEFAULT N'BOOKED', CheckInAt datetime2 NULL,
 CheckOutAt datetime2 NULL, CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_TDPTStay PRIMARY KEY(CompanyID,StayID),
 CONSTRAINT UQ_TDPTStay_BookingPet UNIQUE(CompanyID,BookingID,PetID),
 CONSTRAINT FK_TDPTStay_Booking FOREIGN KEY(CompanyID,BookingID) REFERENCES dbo.TDBKBooking(CompanyID,BookingID),
 CONSTRAINT FK_TDPTStay_Pet FOREIGN KEY(CompanyID,PetID) REFERENCES dbo.TDPTPet(CompanyID,PetID),
 CONSTRAINT FK_TDPTStay_Room FOREIGN KEY(CompanyID,RoomID) REFERENCES dbo.TDPTRoom(CompanyID,RoomID),
 CONSTRAINT CK_TDPTStay_Dates CHECK(EndsAt>StartsAt),
 CONSTRAINT CK_TDPTStay_Status CHECK(StatusCode IN(N'BOOKED',N'CHECKED_IN',N'COMPLETED',N'CANCELLED')));
CREATE INDEX IX_TDPTStay_Overlap ON dbo.TDPTStay(CompanyID,RoomID,StatusCode,StartsAt,EndsAt);
CREATE TABLE dbo.TDPTCareLog(
 CompanyID bigint NOT NULL, CareLogID bigint IDENTITY NOT NULL, StayID bigint NOT NULL,
 EventCode nvarchar(30) NOT NULL, DetailText nvarchar(2000) NULL,
 LoggedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), LoggedBy bigint NOT NULL,
 CONSTRAINT PK_TDPTCareLog PRIMARY KEY(CompanyID,CareLogID),
 CONSTRAINT FK_TDPTCareLog_Stay FOREIGN KEY(CompanyID,StayID) REFERENCES dbo.TDPTStay(CompanyID,StayID));
CREATE TABLE dbo.TDPTPhoto(
 CompanyID bigint NOT NULL, PhotoID bigint IDENTITY NOT NULL, PetID bigint NOT NULL,
 StayID bigint NULL, FilePath nvarchar(500) NOT NULL, MimeType nvarchar(100) NOT NULL,
 FileSize bigint NOT NULL, Sha256 char(64) NOT NULL, CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_TDPTPhoto PRIMARY KEY(CompanyID,PhotoID),
 CONSTRAINT FK_TDPTPhoto_Pet FOREIGN KEY(CompanyID,PetID) REFERENCES dbo.TDPTPet(CompanyID,PetID),
 CONSTRAINT FK_TDPTPhoto_Stay FOREIGN KEY(CompanyID,StayID) REFERENCES dbo.TDPTStay(CompanyID,StayID),
 CONSTRAINT CK_TDPTPhoto_Size CHECK(FileSize>0));
CREATE TABLE dbo.TDPTPackage(
 CompanyID bigint NOT NULL, PackageID bigint IDENTITY NOT NULL, PackageCode nvarchar(30) NOT NULL,
 PackageName nvarchar(150) NOT NULL, Price decimal(18,2) NOT NULL, ValidDays int NOT NULL,
 IncludedUnits int NOT NULL, IsActive bit NOT NULL DEFAULT 1,
 CONSTRAINT PK_TDPTPackage PRIMARY KEY(CompanyID,PackageID),
 CONSTRAINT UQ_TDPTPackage_Code UNIQUE(CompanyID,PackageCode),
 CONSTRAINT CK_TDPTPackage_Values CHECK(Price>=0 AND ValidDays>0 AND IncludedUnits>0));
CREATE TABLE dbo.TDPTPackageService(
 CompanyID bigint NOT NULL, PackageID bigint NOT NULL, ServiceID bigint NOT NULL,
 CONSTRAINT PK_TDPTPackageService PRIMARY KEY(CompanyID,PackageID,ServiceID),
 CONSTRAINT FK_TDPTPackageService_Package FOREIGN KEY(CompanyID,PackageID) REFERENCES dbo.TDPTPackage(CompanyID,PackageID),
 CONSTRAINT FK_TDPTPackageService_Service FOREIGN KEY(CompanyID,ServiceID) REFERENCES dbo.TDPTServiceMap(CompanyID,ServiceID));
CREATE TABLE dbo.TDPTEntitlement(
 CompanyID bigint NOT NULL, EntitlementID bigint IDENTITY NOT NULL, PackageID bigint NOT NULL,
 MemberID bigint NOT NULL, SaleID bigint NULL, StartsOn date NOT NULL, ExpiresOn date NOT NULL,
 UnitsSnapshot int NOT NULL, RemainingUnits int NOT NULL,
 CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_TDPTEntitlement PRIMARY KEY(CompanyID,EntitlementID),
 CONSTRAINT FK_TDPTEntitlement_Package FOREIGN KEY(CompanyID,PackageID) REFERENCES dbo.TDPTPackage(CompanyID,PackageID),
 CONSTRAINT FK_TDPTEntitlement_Member FOREIGN KEY(CompanyID,MemberID) REFERENCES dbo.TDBKMember(CompanyID,MemberID),
 CONSTRAINT CK_TDPTEntitlement_Units CHECK(UnitsSnapshot>0 AND RemainingUnits BETWEEN 0 AND UnitsSnapshot AND ExpiresOn>=StartsOn));
CREATE TABLE dbo.TDPTEntitlementLedger(
 CompanyID bigint NOT NULL, LedgerID bigint IDENTITY NOT NULL, EntitlementID bigint NOT NULL,
 BookingID bigint NULL, DeltaUnits int NOT NULL, ReasonCode nvarchar(30) NOT NULL,
 CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), CreatedBy bigint NOT NULL,
 CONSTRAINT PK_TDPTEntitlementLedger PRIMARY KEY(CompanyID,LedgerID),
 CONSTRAINT FK_TDPTEntitlementLedger_Ent FOREIGN KEY(CompanyID,EntitlementID) REFERENCES dbo.TDPTEntitlement(CompanyID,EntitlementID),
 CONSTRAINT FK_TDPTEntitlementLedger_Booking FOREIGN KEY(CompanyID,BookingID) REFERENCES dbo.TDBKBooking(CompanyID,BookingID),
 CONSTRAINT CK_TDPTEntitlementLedger_Delta CHECK(DeltaUnits<>0));
CREATE UNIQUE INDEX UX_TDPTEntitlementLedger_Consume ON dbo.TDPTEntitlementLedger(CompanyID,EntitlementID,BookingID) WHERE BookingID IS NOT NULL AND DeltaUnits<0;
CREATE TABLE dbo.TDPTAudit(
 CompanyID bigint NOT NULL, AuditID bigint IDENTITY NOT NULL, EntityCode nvarchar(30) NOT NULL,
 EntityID bigint NOT NULL, ActionCode nvarchar(30) NOT NULL, ActorID bigint NULL,
 DetailText nvarchar(2000) NULL, OccurredAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_TDPTAudit PRIMARY KEY(CompanyID,AuditID));
GO
