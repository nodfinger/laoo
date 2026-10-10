SET NOCOUNT ON;
SET XACT_ABORT ON;
CREATE TABLE dbo.TDBKSetting(
 CompanyID bigint NOT NULL PRIMARY KEY,
 AdvanceDays int NOT NULL CONSTRAINT DF_TDBKSetting_Advance DEFAULT(90),
 CancelBeforeHours int NOT NULL CONSTRAINT DF_TDBKSetting_Cancel DEFAULT(2),
 NoShowGraceMinutes int NOT NULL CONSTRAINT DF_TDBKSetting_NoShow DEFAULT(15),
 UpdatedAt datetime2 NOT NULL CONSTRAINT DF_TDBKSetting_Updated DEFAULT SYSUTCDATETIME(),
 UpdatedBy bigint NULL,
 CONSTRAINT CK_TDBKSetting_Values CHECK(AdvanceDays BETWEEN 1 AND 365 AND CancelBeforeHours BETWEEN 0 AND 168 AND NoShowGraceMinutes BETWEEN 0 AND 1440)
);
CREATE TABLE dbo.TDBKPromotion(
 CompanyID bigint NOT NULL,
 PromotionID bigint IDENTITY NOT NULL,
 PromotionCode nvarchar(30) NOT NULL,
 PromotionName nvarchar(150) NOT NULL,
 ServiceID bigint NULL,
 TierCode nvarchar(30) NULL,
 StartsAt datetime2 NOT NULL,
 EndsAt datetime2 NOT NULL,
 DiscountType nvarchar(10) NOT NULL,
 DiscountValue decimal(18,2) NOT NULL,
 IsActive bit NOT NULL CONSTRAINT DF_TDBKPromotion_Active DEFAULT(1),
 CONSTRAINT PK_TDBKPromotion PRIMARY KEY(CompanyID,PromotionID),
 CONSTRAINT UQ_TDBKPromotion_Code UNIQUE(CompanyID,PromotionCode),
 CONSTRAINT FK_TDBKPromotion_Service FOREIGN KEY(CompanyID,ServiceID) REFERENCES dbo.TDBKService(CompanyID,ServiceID),
 CONSTRAINT CK_TDBKPromotion_Valid CHECK(EndsAt>StartsAt AND DiscountValue>0 AND (DiscountType=N'AMOUNT' OR (DiscountType=N'PERCENT' AND DiscountValue<=100)))
);
CREATE INDEX IX_TDBKPromotion_Window ON dbo.TDBKPromotion(CompanyID,IsActive,StartsAt,EndsAt);
CREATE TABLE dbo.TDBKProviderSchedule(
 CompanyID bigint NOT NULL,
 ProviderID bigint NOT NULL,
 WeekdayNumber tinyint NOT NULL,
 StartsAt time NOT NULL,
 EndsAt time NOT NULL,
 CONSTRAINT PK_TDBKProviderSchedule PRIMARY KEY(CompanyID,ProviderID,WeekdayNumber,StartsAt),
 CONSTRAINT FK_TDBKProviderSchedule_Provider FOREIGN KEY(CompanyID,ProviderID) REFERENCES dbo.TDBKProvider(CompanyID,ProviderID),
 CONSTRAINT CK_TDBKProviderSchedule_Valid CHECK(WeekdayNumber BETWEEN 1 AND 7 AND EndsAt>StartsAt)
);
CREATE TABLE dbo.TDBKProviderService(
 CompanyID bigint NOT NULL,
 ProviderID bigint NOT NULL,
 ServiceID bigint NOT NULL,
 CONSTRAINT PK_TDBKProviderService PRIMARY KEY(CompanyID,ProviderID,ServiceID),
 CONSTRAINT FK_TDBKProviderService_Provider FOREIGN KEY(CompanyID,ProviderID) REFERENCES dbo.TDBKProvider(CompanyID,ProviderID),
 CONSTRAINT FK_TDBKProviderService_Service FOREIGN KEY(CompanyID,ServiceID) REFERENCES dbo.TDBKService(CompanyID,ServiceID)
);
CREATE TABLE dbo.TDBKResourceService(
 CompanyID bigint NOT NULL,
 ResourceID bigint NOT NULL,
 ServiceID bigint NOT NULL,
 CONSTRAINT PK_TDBKResourceService PRIMARY KEY(CompanyID,ResourceID,ServiceID),
 CONSTRAINT FK_TDBKResourceService_Resource FOREIGN KEY(CompanyID,ResourceID) REFERENCES dbo.TDBKResource(CompanyID,ResourceID),
 CONSTRAINT FK_TDBKResourceService_Service FOREIGN KEY(CompanyID,ServiceID) REFERENCES dbo.TDBKService(CompanyID,ServiceID)
);
ALTER TABLE dbo.TDBKBooking ADD Note nvarchar(2000) NULL;
ALTER TABLE dbo.TDBKBookingService ADD PromotionIDSnapshot bigint NULL;
CREATE UNIQUE INDEX UX_TDBKMember_Person ON dbo.TDBKMember(CompanyID,PersonID);
CREATE TABLE dbo.TDBKUsage(
 CompanyID bigint NOT NULL,
 BookingID bigint NOT NULL,
 LineID bigint NOT NULL,
 UsedAt datetime2 NOT NULL CONSTRAINT DF_TDBKUsage_UsedAt DEFAULT SYSUTCDATETIME(),
 UsedBy bigint NOT NULL,
 CONSTRAINT PK_TDBKUsage PRIMARY KEY(CompanyID,BookingID,LineID),
 CONSTRAINT FK_TDBKUsage_Line FOREIGN KEY(CompanyID,BookingID,LineID) REFERENCES dbo.TDBKBookingService(CompanyID,BookingID,LineID)
);
CREATE TABLE dbo.TDBKSaleLink(
 CompanyID bigint NOT NULL,
 BookingID bigint NOT NULL,
 SaleID bigint NOT NULL,
 LinkedAt datetime2 NOT NULL CONSTRAINT DF_TDBKSaleLink_LinkedAt DEFAULT SYSUTCDATETIME(),
 LinkedBy bigint NOT NULL,
 CONSTRAINT PK_TDBKSaleLink PRIMARY KEY(CompanyID,BookingID,SaleID),
 CONSTRAINT UQ_TDBKSaleLink_Sale UNIQUE(CompanyID,SaleID),
 CONSTRAINT FK_TDBKSaleLink_Booking FOREIGN KEY(CompanyID,BookingID) REFERENCES dbo.TDBKBooking(CompanyID,BookingID)
);
CREATE TABLE dbo.TDBKBookingAudit(
 CompanyID bigint NOT NULL,
 AuditID bigint IDENTITY NOT NULL,
 BookingID bigint NOT NULL,
 ActionCode nvarchar(30) NOT NULL,
 ActorUserID bigint NOT NULL,
 Reason nvarchar(500) NULL,
 OccurredAt datetime2 NOT NULL CONSTRAINT DF_TDBKBookingAudit_At DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_TDBKBookingAudit PRIMARY KEY(CompanyID,AuditID),
 CONSTRAINT FK_TDBKBookingAudit_Booking FOREIGN KEY(CompanyID,BookingID) REFERENCES dbo.TDBKBooking(CompanyID,BookingID)
);
CREATE INDEX IX_TDBKBookingAudit_Booking ON dbo.TDBKBookingAudit(CompanyID,BookingID,OccurredAt);
DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_BOOKING');
IF @ProjectID IS NULL THROW 61011,N'Booking bootstrap is required',1;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,M.MenuCode,M.MenuName,M.RouteName,A.ActionCode,A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM (VALUES(N'61003',N'DELETE'),(N'61004',N'DELETE'),(N'61005',N'DELETE'),(N'61006',N'DELETE'),(N'61008',N'SALE')) A(MenuCode,ActionCode)
JOIN dbo.TDADMainMenu M ON M.MenuCode=A.MenuCode
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ProjectID AND P.ScreenCode=A.MenuCode AND P.ActionCode=A.ActionCode);
UPDATE dbo.TDADMainMenu SET IsVisible=1 WHERE MenuCode BETWEEN N'61001' AND N'61010';
