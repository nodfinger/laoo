SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_BOOKING') THROW 61001,N'Project exists',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'61001' AND N'61010') THROW 61002,N'Menu conflict',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'61') THROW 61003,N'Group conflict',1;
INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault) VALUES(N'LAOO_BOOKING',N'ระบบจองคิวและสมาชิก',N'Booking',N'Multi-service booking',1,SYSUTCDATETIME(),N'BUSINESS',230,N'event_available',0);
DECLARE @P bigint=SCOPE_IDENTITY();
INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption) VALUES(N'C',N'61',N'ระบบจองคิวและสมาชิก',N'event_available',610,0,1,SYSUTCDATETIME(),0,0);
DECLARE @M TABLE(Code char(5),Name nvarchar(150),ST int,Route nvarchar(150),Icon nvarchar(100),Sort int);
INSERT @M VALUES
(N'61001',N'ตั้งค่าระบบจองคิว',2,N'booking-settings',N'settings_outlined',10),
(N'61002',N'ประเภทบริการ',1,N'booking-services',N'event_available',20),
(N'61003',N'ผู้ให้บริการและตารางเวลา',1,N'booking-providers',N'people_outlined',30),
(N'61004',N'ทรัพยากรและห้อง',1,N'booking-resources',N'room_outlined',40),
(N'61005',N'สมาชิก',1,N'booking-members',N'card_membership_outlined',50),
(N'61006',N'โปรโมชั่น',1,N'booking-promotions',N'local_offer_outlined',60),
(N'61007',N'ปฏิทินและรายการจอง',4,N'booking-calendar',N'calendar_month_outlined',70),
(N'61008',N'บันทึกใช้บริการและขาย',4,N'booking-usage',N'point_of_sale_outlined',80),
(N'61009',N'ประวัติสมาชิก',3,N'booking-member-history',N'history_outlined',90),
(N'61010',N'Dashboard และรายงาน',3,N'booking-dashboard',N'analytics_outlined',100);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
SELECT Code,N'61',Name,ST,Route,N'/company/'+Route,N'BOOKING_'+Code,Icon,Sort,0,1,1,SYSUTCDATETIME(),0 FROM @M;
INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@P,N'61',1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @P,Code,N'61',Sort,1,SYSUTCDATETIME() FROM @M;
DECLARE @A TABLE(Code char(5),Act nvarchar(50));
INSERT @A SELECT Code,N'VIEW' FROM @M;
INSERT @A VALUES
(N'61001',N'EDIT'),(N'61002',N'CREATE'),(N'61002',N'EDIT'),(N'61002',N'DELETE'),
(N'61003',N'CREATE'),(N'61003',N'EDIT'),(N'61004',N'CREATE'),(N'61004',N'EDIT'),
(N'61005',N'CREATE'),(N'61005',N'EDIT'),(N'61006',N'CREATE'),(N'61006',N'EDIT'),
(N'61007',N'CREATE'),(N'61007',N'EDIT'),(N'61007',N'CANCEL'),(N'61008',N'USE'),
(N'61008',N'NOSHOW'),(N'61010',N'EXPORT');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @P,A.Code,M.Name,M.Route,A.Act,A.Act,A.Act,1,SYSUTCDATETIME() FROM @A A JOIN @M M ON M.Code=A.Code;
INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive) VALUES(@P,N'STANDARD',N'มาตรฐาน',N'STANDARD',N'MONTHLY',20,1);
INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled) SELECT X.PackageID,N'BOOKING_'+M.Code,1 FROM dbo.TDADProjectPackage X CROSS JOIN @M M WHERE X.ProjectID=@P;
CREATE SEQUENCE dbo.TDBKBookingNoSeq AS bigint START WITH 1 INCREMENT BY 1;
CREATE TABLE dbo.TDBKService(CompanyID bigint NOT NULL,ServiceID bigint IDENTITY NOT NULL,ServiceCode nvarchar(30) NOT NULL,ServiceName nvarchar(150) NOT NULL,DurationMinutes int NOT NULL,Price decimal(18,2) NOT NULL,RequiresProvider bit NOT NULL DEFAULT 0,RequiresResource bit NOT NULL DEFAULT 0,IsActive bit NOT NULL DEFAULT 1,CONSTRAINT PK_TDBKService PRIMARY KEY(CompanyID,ServiceID),CONSTRAINT UQ_TDBKService_Code UNIQUE(CompanyID,ServiceCode),CONSTRAINT CK_TDBKService CHECK(DurationMinutes>0 AND Price>=0));
CREATE TABLE dbo.TDBKMember(CompanyID bigint NOT NULL,MemberID bigint IDENTITY NOT NULL,PersonID bigint NOT NULL,MemberCode nvarchar(30) NOT NULL,TierCode nvarchar(30) NOT NULL,StartsOn date NOT NULL,ExpiresOn date NULL,IsActive bit NOT NULL DEFAULT 1,CONSTRAINT PK_TDBKMember PRIMARY KEY(CompanyID,MemberID),CONSTRAINT UQ_TDBKMember_Code UNIQUE(CompanyID,MemberCode),CONSTRAINT FK_TDBKMember_Person FOREIGN KEY(CompanyID,PersonID) REFERENCES dbo.TDADPerson(CompanyID,PersonID));
CREATE TABLE dbo.TDBKProvider(CompanyID bigint NOT NULL,ProviderID bigint IDENTITY NOT NULL,PersonID bigint NOT NULL,IsActive bit NOT NULL DEFAULT 1,CONSTRAINT PK_TDBKProvider PRIMARY KEY(CompanyID,ProviderID),CONSTRAINT UQ_TDBKProvider_Person UNIQUE(CompanyID,PersonID),CONSTRAINT FK_TDBKProvider_Person FOREIGN KEY(CompanyID,PersonID) REFERENCES dbo.TDADPerson(CompanyID,PersonID));
CREATE TABLE dbo.TDBKResource(CompanyID bigint NOT NULL,ResourceID bigint IDENTITY NOT NULL,BranchID bigint NULL,ResourceName nvarchar(150) NOT NULL,ResourceType nvarchar(30) NOT NULL,IsActive bit NOT NULL DEFAULT 1,CONSTRAINT PK_TDBKResource PRIMARY KEY(CompanyID,ResourceID));
CREATE TABLE dbo.TDBKBooking(CompanyID bigint NOT NULL,BookingID bigint IDENTITY NOT NULL,BookingNo nvarchar(30) NOT NULL,MemberID bigint NULL,GuestName nvarchar(150) NULL,GuestPhone nvarchar(50) NULL,BranchID bigint NULL,StartsAt datetime2 NOT NULL,EndsAt datetime2 NOT NULL,StatusCode nvarchar(20) NOT NULL,TotalAmount decimal(18,2) NOT NULL,CreatedBy bigint NOT NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),CONSTRAINT PK_TDBKBooking PRIMARY KEY(CompanyID,BookingID),CONSTRAINT UQ_TDBKBooking_No UNIQUE(CompanyID,BookingNo),CONSTRAINT FK_TDBKBooking_Member FOREIGN KEY(CompanyID,MemberID) REFERENCES dbo.TDBKMember(CompanyID,MemberID),CONSTRAINT CK_TDBKBooking_Period CHECK(EndsAt>StartsAt));
CREATE TABLE dbo.TDBKBookingService(CompanyID bigint NOT NULL,BookingID bigint NOT NULL,LineID bigint IDENTITY NOT NULL,ServiceID bigint NOT NULL,ProviderID bigint NULL,ResourceID bigint NULL,PriceSnapshot decimal(18,2) NOT NULL,DiscountSnapshot decimal(18,2) NOT NULL DEFAULT 0,NetAmount decimal(18,2) NOT NULL,CONSTRAINT PK_TDBKBookingService PRIMARY KEY(CompanyID,BookingID,LineID),CONSTRAINT FK_TDBKBS_Booking FOREIGN KEY(CompanyID,BookingID) REFERENCES dbo.TDBKBooking(CompanyID,BookingID),CONSTRAINT FK_TDBKBS_Service FOREIGN KEY(CompanyID,ServiceID) REFERENCES dbo.TDBKService(CompanyID,ServiceID),CONSTRAINT FK_TDBKBS_Provider FOREIGN KEY(CompanyID,ProviderID) REFERENCES dbo.TDBKProvider(CompanyID,ProviderID),CONSTRAINT FK_TDBKBS_Resource FOREIGN KEY(CompanyID,ResourceID) REFERENCES dbo.TDBKResource(CompanyID,ResourceID));
CREATE INDEX IX_TDBKBooking_Period ON dbo.TDBKBooking(CompanyID,StatusCode,StartsAt,EndsAt);
CREATE INDEX IX_TDBKBookingService_Service ON dbo.TDBKBookingService(CompanyID,ServiceID,BookingID);
GO
