SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @prefix nvarchar(30)=N'MK261008';
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@co AND Username=N'c111');
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MARKET');
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD');
IF @co IS NULL OR @actor IS NULL OR @partner IS NULL OR @project IS NULL OR @package IS NULL
 THROW 59201,N'Market DEMO prerequisites missing.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1)
BEGIN
 INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,ReasonText,CreateBy)
 VALUES(@partner,@co,@project,@package,N'TRIAL',CONVERT(date,SYSUTCDATETIME()),DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),N'MK_20261008_DEMO acceptance test',@actor);
 INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,1,1,CONVERT(date,SYSUTCDATETIME()),DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),@actor
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@project);
 INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,F.FeatureCode,1,1,CONVERT(date,SYSUTCDATETIME()),DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),@actor
 FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=@package AND F.IsEnabled=1;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@co AND UserID=@actor AND ProjectID=@project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
 VALUES(@co,@actor,@project,0,1,SYSUTCDATETIME(),@actor);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @actor,@project,P.PermissionID,1,1,N'MK_20261008_DEMO',@actor
FROM dbo.TDADPermission P WHERE P.ProjectID=@project AND P.IsActive=1
AND P.ScreenCode IN(N'59003',N'59004')
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U
 WHERE U.UserID=@actor AND U.ProjectID=@project AND U.PermissionID=P.PermissionID);
DECLARE @branch bigint=(SELECT TOP(1) BranchID FROM dbo.TDADBranch WHERE CompanyID=@co AND IsActive=1 ORDER BY BranchID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKMarket WHERE CompanyID=@co AND MarketCode=@prefix)
 INSERT dbo.TDMKMarket(CompanyID,BranchID,MarketCode,MarketName)
 VALUES(@co,@branch,@prefix,N'ตลาดตัวอย่าง LAOO');
DECLARE @market bigint=(SELECT MarketID FROM dbo.TDMKMarket WHERE CompanyID=@co AND MarketCode=@prefix);
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKZone WHERE CompanyID=@co AND MarketID=@market AND ZoneCode=N'A')
 INSERT dbo.TDMKZone(CompanyID,MarketID,ZoneCode,ZoneName) VALUES(@co,@market,N'A',N'โซน A · ของสด');
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKZone WHERE CompanyID=@co AND MarketID=@market AND ZoneCode=N'B')
 INSERT dbo.TDMKZone(CompanyID,MarketID,ZoneCode,ZoneName) VALUES(@co,@market,N'B',N'โซน B · อาหาร');
DECLARE @zoneA bigint=(SELECT ZoneID FROM dbo.TDMKZone WHERE CompanyID=@co AND MarketID=@market AND ZoneCode=N'A');
DECLARE @zoneB bigint=(SELECT ZoneID FROM dbo.TDMKZone WHERE CompanyID=@co AND MarketID=@market AND ZoneCode=N'B');
INSERT dbo.TDMKStall(CompanyID,MarketID,ZoneID,StallCode,PosX,PosY)
SELECT @co,@market,CASE WHEN V.Code LIKE N'A%' THEN @zoneA ELSE @zoneB END,V.Code,V.X,V.Y
FROM (VALUES(N'A01',0,0),(N'A02',1,0),(N'A03',2,0),(N'A04',3,0),(N'B01',0,1),(N'B02',1,1)) V(Code,X,Y)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDMKStall S WHERE S.CompanyID=@co AND S.MarketID=@market AND S.StallCode=V.Code);
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKTrader WHERE CompanyID=@co AND Phone=N'0800005901')
 INSERT dbo.TDMKTrader(CompanyID,TraderName,Phone) VALUES(@co,N'ผู้ค้าเก่า ตัวอย่างตลาด',N'0800005901');
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKTrader WHERE CompanyID=@co AND Phone=N'0800005902')
 INSERT dbo.TDMKTrader(CompanyID,TraderName,Phone) VALUES(@co,N'ผู้สนใจใหม่ ตัวอย่างตลาด',N'0800005902');
DECLARE @old bigint=(SELECT TraderID FROM dbo.TDMKTrader WHERE CompanyID=@co AND Phone=N'0800005901');
DECLARE @a03 bigint=(SELECT StallID FROM dbo.TDMKStall WHERE CompanyID=@co AND MarketID=@market AND StallCode=N'A03');
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKContract WHERE CompanyID=@co AND StallID=@a03 AND TraderID=@old)
 INSERT dbo.TDMKContract(CompanyID,StallID,TraderID,StartsOn,EndsOn,RentCycleCode,StatusCode)
 VALUES(@co,@a03,@old,DATEADD(day,-30,CONVERT(date,SYSUTCDATETIME())),DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),N'MONTHLY',N'ACTIVE');
DECLARE @b01 bigint=(SELECT StallID FROM dbo.TDMKStall WHERE CompanyID=@co AND MarketID=@market AND StallCode=N'B01');
DECLARE @b02 bigint=(SELECT StallID FROM dbo.TDMKStall WHERE CompanyID=@co AND MarketID=@market AND StallCode=N'B02');
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKStallStatusPeriod WHERE CompanyID=@co AND StallID=@b01 AND IsActive=1)
 INSERT dbo.TDMKStallStatusPeriod(CompanyID,StallID,StatusCode,StartsOn,Reason)
 VALUES(@co,@b01,N'CLOSED',DATEADD(day,-5,CONVERT(date,SYSUTCDATETIME())),N'MK_20261008_DEMO ปิดปรับพื้นที่');
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKStallStatusPeriod WHERE CompanyID=@co AND StallID=@b02 AND IsActive=1)
 INSERT dbo.TDMKStallStatusPeriod(CompanyID,StallID,StatusCode,StartsOn,EndsOn,Reason)
 VALUES(@co,@b02,N'RENOVATION',CONVERT(date,SYSUTCDATETIME()),DATEADD(day,15,CONVERT(date,SYSUTCDATETIME())),N'MK_20261008_DEMO ซ่อมพื้น');
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKInquiry WHERE CompanyID=@co AND MarketID=@market AND Phone=N'0800005902')
 INSERT dbo.TDMKInquiry(CompanyID,MarketID,ContactName,Phone,Requirement)
 VALUES(@co,@market,N'ผู้สนใจใหม่ ตัวอย่างตลาด',N'0800005902',N'ต้องการล็อกขายอาหารขนาด 3 × 3 เมตร');
DECLARE @a02 bigint=(SELECT StallID FROM dbo.TDMKStall WHERE CompanyID=@co AND MarketID=@market AND StallCode=N'A02');
IF NOT EXISTS(SELECT 1 FROM dbo.TDMKBooking WHERE CompanyID=@co AND StallID=@a02
 AND StatusCode=N'RESERVED' AND ExpiresAt>SYSUTCDATETIME()
 AND StartsOn<=CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME()))
 AND EndsOn>=CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME())))
BEGIN
 DECLARE @sampleBooking bigint;
 INSERT dbo.TDMKBooking(CompanyID,StallID,TraderID,StartsOn,EndsOn,ExpiresAt,StatusCode,IdempotencyKey,CreatedBy)
 VALUES(@co,@a02,@old,CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME())),
  DATEADD(day,7,CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME()))),
  DATEADD(hour,24,SYSUTCDATETIME()),N'RESERVED',NEWID(),@actor);
 SET @sampleBooking=SCOPE_IDENTITY();
 INSERT dbo.TDMKAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID,Remark)
 VALUES(@co,@actor,N'RESERVE',N'BOOKING',@sampleBooking,N'MK_20261008_DEMO sample reservation');
END;
-- Only the implemented map/booking screen is visible; unfinished menus stay hidden.
UPDATE dbo.TDADMainMenu SET IsVisible=1 WHERE MenuCode=N'59003';
COMMIT TRAN;
