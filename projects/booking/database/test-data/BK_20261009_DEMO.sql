-- Booking acceptance fixture. DEMO only; every new business row carries this Run ID.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @run nvarchar(40)=N'BK_20261009_DEMO';
DECLARE @today date=CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
DECLARE @company bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_BOOKING' AND IsActive=1);
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@company AND Username=N'c111' AND IsActive=1);
DECLARE @branch bigint=(SELECT BranchID FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchCode=N'P110' AND IsActive=1);
DECLARE @memberPerson bigint=(SELECT TOP(1) PersonID FROM dbo.TDADPerson WHERE CompanyID=@company AND FullName=N'โชคชัย  วันดี' AND IsActive=1 ORDER BY PersonID);
DECLARE @providerPerson bigint=(SELECT TOP(1) PersonID FROM dbo.TDADPerson WHERE CompanyID=@company AND FullName=N'โชคดี' AND IsActive=1 ORDER BY PersonID);
IF @company IS NULL OR @partner IS NULL OR @project IS NULL OR @package IS NULL OR @actor IS NULL OR @branch IS NULL OR @memberPerson IS NULL OR @providerPerson IS NULL
 THROW 61100,N'Booking DEMO prerequisites are missing',1;
IF EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1 AND ISNULL(ReasonText,N'')<>@run)
 THROW 61101,N'Another current Booking subscription exists; do not overwrite it',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1)
BEGIN
 DECLARE @subscription bigint;
 INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText,CreateBy)
 VALUES(@partner,@company,@project,@package,N'TRIAL',@today,DATEADD(day,30,@today),1,@run,@actor);
 SET @subscription=SCOPE_IDENTITY();
 INSERT dbo.TDADCompanyProjectSubscriptionAudit(SubscriptionID,PartnerID,CompanyID,ProjectID,PackageID,ActionCode,BeforeJson,AfterJson,ReasonText,ActorType,ActorID)
 VALUES(@subscription,@partner,@company,@project,@package,N'ASSIGN',NULL,CONCAT(N'{"runId":"',@run,N'","status":"TRIAL"}'),@run,N'TEST_FIXTURE',@actor);
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@company AND ProjectID=@project)
 INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 VALUES(@partner,@company,@project,1,1,@today,DATEADD(day,30,@today),@actor);
INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
SELECT @partner,@company,@project,F.FeatureCode,1,1,@today,DATEADD(day,30,@today),@actor
FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=@package AND F.IsEnabled=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyFeature C WHERE C.CompanyID=@company AND C.ProjectID=@project AND C.FeatureCode=F.FeatureCode);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@company AND UserID=@actor AND ProjectID=@project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
 VALUES(@company,@actor,@project,0,1,SYSUTCDATETIME(),@actor);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @actor,@project,P.PermissionID,1,1,@run,@actor FROM dbo.TDADPermission P
WHERE P.ProjectID=@project AND P.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U WHERE U.UserID=@actor AND U.ProjectID=@project AND U.PermissionID=P.PermissionID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKSetting WHERE CompanyID=@company)
 INSERT dbo.TDBKSetting(CompanyID,AdvanceDays,CancelBeforeHours,NoShowGraceMinutes,UpdatedBy) VALUES(@company,90,2,15,@actor);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKService WHERE CompanyID=@company AND ServiceCode=N'BK26_GROOM')
 INSERT dbo.TDBKService(CompanyID,ServiceCode,ServiceName,DurationMinutes,Price,RequiresProvider,RequiresResource)
 VALUES(@company,N'BK26_GROOM',N'อาบน้ำตัดขน [BK_20261009_DEMO]',60,300,0,0);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKService WHERE CompanyID=@company AND ServiceCode=N'BK26_PICKUP')
 INSERT dbo.TDBKService(CompanyID,ServiceCode,ServiceName,DurationMinutes,Price,RequiresProvider,RequiresResource)
 VALUES(@company,N'BK26_PICKUP',N'รับส่งสัตว์เลี้ยง [BK_20261009_DEMO]',30,150,0,0);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKService WHERE CompanyID=@company AND ServiceCode=N'BK26_COURT')
 INSERT dbo.TDBKService(CompanyID,ServiceCode,ServiceName,DurationMinutes,Price,RequiresProvider,RequiresResource)
 VALUES(@company,N'BK26_COURT',N'จองสนามกีฬา [BK_20261009_DEMO]',90,500,0,1);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKMember WHERE CompanyID=@company AND PersonID=@memberPerson)
 INSERT dbo.TDBKMember(CompanyID,PersonID,MemberCode,TierCode,StartsOn,ExpiresOn)
 VALUES(@company,@memberPerson,N'BK26_MEMBER',N'GOLD',@today,DATEADD(year,1,@today));
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKProvider WHERE CompanyID=@company AND PersonID=@providerPerson)
 INSERT dbo.TDBKProvider(CompanyID,PersonID) VALUES(@company,@providerPerson);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKResource WHERE CompanyID=@company AND ResourceName=N'สนาม 1 [BK_20261009_DEMO]')
 INSERT dbo.TDBKResource(CompanyID,BranchID,ResourceName,ResourceType) VALUES(@company,@branch,N'สนาม 1 [BK_20261009_DEMO]',N'COURT');
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKPromotion WHERE CompanyID=@company AND PromotionCode=N'BK26_GOLD10')
 INSERT dbo.TDBKPromotion(CompanyID,PromotionCode,PromotionName,ServiceID,TierCode,StartsAt,EndsAt,DiscountType,DiscountValue)
 VALUES(@company,N'BK26_GOLD10',N'ส่วนลดสมาชิก 10% [BK_20261009_DEMO]',NULL,N'GOLD',DATEADD(day,-1,SYSUTCDATETIME()),DATEADD(day,30,SYSUTCDATETIME()),N'PERCENT',10);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKBooking WHERE CompanyID=@company AND BookingNo=N'BKSEED261009-NOSHOW')
BEGIN
 DECLARE @seedBooking bigint;
 INSERT dbo.TDBKBooking(CompanyID,BookingNo,GuestName,GuestPhone,BranchID,StartsAt,EndsAt,StatusCode,TotalAmount,CreatedBy,Note)
 VALUES(@company,N'BKSEED261009-NOSHOW',N'ลูกค้าทดสอบไม่มา',N'0000000000',@branch,DATEADD(day,-2,SYSUTCDATETIME()),DATEADD(day,-2,DATEADD(hour,1,SYSUTCDATETIME())),N'BOOKED',300,@actor,@run);
 SET @seedBooking=SCOPE_IDENTITY();
 INSERT dbo.TDBKBookingService(CompanyID,BookingID,ServiceID,PriceSnapshot,DiscountSnapshot,NetAmount)
 VALUES(@company,@seedBooking,(SELECT ServiceID FROM dbo.TDBKService WHERE CompanyID=@company AND ServiceCode=N'BK26_GROOM'),300,0,300);
 INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID,Reason)
 VALUES(@company,@seedBooking,N'SEED',@actor,@run);
END;
