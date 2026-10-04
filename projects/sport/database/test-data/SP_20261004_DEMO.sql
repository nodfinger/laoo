SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @branch bigint=(SELECT TOP(1) BranchID FROM dbo.TDADBranch WHERE CompanyID=@co AND BranchCode=N'HO');
IF @co IS NULL OR @branch IS NULL THROW 57501,N'DEMO company/HO branch missing',1;
DECLARE @prefix nvarchar(20)=N'SP261004';
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@co AND Username=N'c111' AND IsActive=1);
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SPORT');
DECLARE @packageMaster bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD');
IF @actor IS NULL OR @partner IS NULL OR @packageMaster IS NULL THROW 57504,N'Sport demo entitlement prerequisites missing',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1)
BEGIN
 INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,ReasonText,CreateBy)
 VALUES(@partner,@co,@project,@packageMaster,N'TRIAL',CONVERT(date,SYSUTCDATETIME()),
 DATEADD(day,60,CONVERT(date,SYSUTCDATETIME())),N'SP_20261004_DEMO acceptance test',@actor);
 INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,1,1,CONVERT(date,SYSUTCDATETIME()),
 DATEADD(day,60,CONVERT(date,SYSUTCDATETIME())),@actor
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@project);
 INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,F.FeatureCode,1,1,CONVERT(date,SYSUTCDATETIME()),
 DATEADD(day,60,CONVERT(date,SYSUTCDATETIME())),@actor
 FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=@packageMaster AND F.IsEnabled=1;
 INSERT dbo.TDSPAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID,Detail)
 VALUES(@co,@actor,N'DEMO_ENABLE',N'PROJECT',@project,N'SP_20261004_DEMO trial 60 days');
END;
DECLARE @trialStart date;
SELECT @trialStart=StartDate
FROM dbo.TDADCompanyProjectSubscription
WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1
  AND StatusCode=N'TRIAL' AND ReasonText=N'SP_20261004_DEMO acceptance test';
IF @trialStart IS NOT NULL
BEGIN
 DECLARE @trialEnd date=DATEADD(day,60,@trialStart);
 UPDATE dbo.TDADCompanyProjectSubscription
 SET ExpireDate=@trialEnd
 WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1
   AND StatusCode=N'TRIAL' AND ReasonText=N'SP_20261004_DEMO acceptance test'
   AND (ExpireDate IS NULL OR ExpireDate<>@trialEnd);
 IF @@ROWCOUNT>0
 BEGIN
  UPDATE dbo.TDADCompanyProject SET ExpireDate=@trialEnd
  WHERE CompanyID=@co AND ProjectID=@project AND IsTrial=1;
  UPDATE dbo.TDADCompanyFeature SET ExpireDate=@trialEnd
  WHERE CompanyID=@co AND ProjectID=@project AND IsTrial=1;
  INSERT dbo.TDSPAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID,Detail)
  VALUES(@co,@actor,N'DEMO_EXTEND',N'PROJECT',@project,N'SP_20261004_DEMO trial 60 days');
 END;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@co AND UserID=@actor AND ProjectID=@project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
 VALUES(@co,@actor,@project,0,1,SYSUTCDATETIME(),@actor);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @actor,@project,P.PermissionID,1,1,N'SP_20261004_DEMO',@actor
FROM dbo.TDADPermission P WHERE P.ProjectID=@project AND P.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U WHERE U.UserID=@actor AND U.ProjectID=@project AND U.PermissionID=P.PermissionID);

INSERT dbo.TDADPerson(CompanyID,FullName,NickName,Email,IsActive,CreateDate)
SELECT @co,N'สมาชิกตัวอย่าง กีฬา A '+@prefix,N'กีฬา A',N'sport-a-261004@example.invalid',1,SYSUTCDATETIME()
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPerson WHERE CompanyID=@co AND Email=N'sport-a-261004@example.invalid');
INSERT dbo.TDADPerson(CompanyID,FullName,NickName,Email,IsActive,CreateDate)
SELECT @co,N'สมาชิกตัวอย่าง กีฬา B '+@prefix,N'กีฬา B',N'sport-b-261004@example.invalid',1,SYSUTCDATETIME()
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPerson WHERE CompanyID=@co AND Email=N'sport-b-261004@example.invalid');

INSERT dbo.TDSPSportType(CompanyID,SportCode,SportName)
SELECT @co,V.Code,V.Name FROM (VALUES
(@prefix+N'_FIT',N'ฟิตเนส'),(@prefix+N'_BAS',N'บาสเกตบอล'),(@prefix+N'_BAD',N'แบดมินตัน')) V(Code,Name)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSPSportType S WHERE S.CompanyID=@co AND S.SportCode=V.Code);
INSERT dbo.TDSPMemberLevel(CompanyID,LevelCode,LevelName,RequiresResident)
SELECT @co,V.Code,V.Name,V.Resident FROM (VALUES
(@prefix+N'_STD',N'สมาชิกทั่วไป',0),(@prefix+N'_RES',N'ผู้พักอาศัย',1)) V(Code,Name,Resident)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSPMemberLevel L WHERE L.CompanyID=@co AND L.LevelCode=V.Code);
DECLARE @standard bigint=(SELECT LevelID FROM dbo.TDSPMemberLevel WHERE CompanyID=@co AND LevelCode=@prefix+N'_STD');
IF EXISTS(SELECT 1 FROM dbo.TDIVItemPriceLevel WHERE CompanyID=@co AND PriceLevelCode=N'00002')
AND NOT EXISTS(SELECT 1 FROM dbo.TDSPPosPriceRule WHERE CompanyID=@co AND LevelID=@standard)
 INSERT dbo.TDSPPosPriceRule(CompanyID,LevelID,PriceLevelCode,IsActive)
 VALUES(@co,@standard,N'00002',1);
INSERT dbo.TDSPMember(CompanyID,PersonID,MemberCode,LevelID,BirthDate,GenderCode)
SELECT @co,P.PersonID,@prefix+N'_A',@standard,'1998-04-12',N'FEMALE'
FROM dbo.TDADPerson P WHERE P.CompanyID=@co AND P.Email=N'sport-a-261004@example.invalid'
AND NOT EXISTS(SELECT 1 FROM dbo.TDSPMember M WHERE M.CompanyID=@co AND M.PersonID=P.PersonID);
INSERT dbo.TDSPMember(CompanyID,PersonID,MemberCode,LevelID,BirthDate,GenderCode)
SELECT @co,P.PersonID,@prefix+N'_B',@standard,NULL,N'UNSPECIFIED'
FROM dbo.TDADPerson P WHERE P.CompanyID=@co AND P.Email=N'sport-b-261004@example.invalid'
AND NOT EXISTS(SELECT 1 FROM dbo.TDSPMember M WHERE M.CompanyID=@co AND M.PersonID=P.PersonID);

INSERT dbo.TDSPFacility(CompanyID,BranchID,SportTypeID,FacilityCode,FacilityName,Capacity)
SELECT @co,@branch,S.SportTypeID,@prefix+V.Suffix,V.Name,1
FROM (VALUES(N'_FIT',N'_F1',N'ห้องฟิตเนสตัวอย่าง'),
(N'_BAS',N'_B1',N'สนามบาสตัวอย่าง'),(N'_BAD',N'_D1',N'สนามแบดตัวอย่าง')) V(SportSuffix,Suffix,Name)
JOIN dbo.TDSPSportType S ON S.CompanyID=@co AND S.SportCode=@prefix+V.SportSuffix
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSPFacility F WHERE F.CompanyID=@co AND F.FacilityCode=@prefix+V.Suffix);
INSERT dbo.TDSPFacilityHours(CompanyID,FacilityID,DayOfWeek,OpensAt,ClosesAt)
SELECT @co,F.FacilityID,D.DayNo,'06:00','22:00'
FROM dbo.TDSPFacility F
CROSS JOIN (VALUES(0),(1),(2),(3),(4),(5),(6)) D(DayNo)
WHERE F.CompanyID=@co AND F.FacilityCode LIKE @prefix+N'_%'
AND NOT EXISTS(SELECT 1 FROM dbo.TDSPFacilityHours H WHERE H.CompanyID=@co AND H.FacilityID=F.FacilityID AND H.DayOfWeek=D.DayNo);

INSERT dbo.TDSPPackage(CompanyID,PackageCode,PackageName,LevelID,DurationDays,QuotaUnit,QuotaAmount,Price)
SELECT @co,@prefix+V.Suffix,V.Name,@standard,V.Days,V.Unit,V.Quota,V.Price
FROM (VALUES(N'_DAY',N'เล่นรายครั้ง',1,N'VISIT',CONVERT(decimal(12,2),1),CONVERT(decimal(18,2),120)),
(N'_MULTI',N'รายปีหลายกีฬา',365,N'VISIT',CONVERT(decimal(12,2),120),CONVERT(decimal(18,2),5990))) V(Suffix,Name,Days,Unit,Quota,Price)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSPPackage P WHERE P.CompanyID=@co AND P.PackageCode=@prefix+V.Suffix);
INSERT dbo.TDSPPackageSport(CompanyID,PackageID,SportTypeID)
SELECT @co,P.PackageID,S.SportTypeID
FROM dbo.TDSPPackage P JOIN dbo.TDSPSportType S ON S.CompanyID=P.CompanyID
WHERE P.CompanyID=@co AND P.PackageCode=@prefix+N'_MULTI' AND S.SportCode LIKE @prefix+N'_%'
AND NOT EXISTS(SELECT 1 FROM dbo.TDSPPackageSport X WHERE X.CompanyID=@co AND X.PackageID=P.PackageID AND X.SportTypeID=S.SportTypeID);
INSERT dbo.TDSPPackageSport(CompanyID,PackageID,SportTypeID)
SELECT @co,P.PackageID,S.SportTypeID
FROM dbo.TDSPPackage P JOIN dbo.TDSPSportType S ON S.CompanyID=P.CompanyID AND S.SportCode=@prefix+N'_BAS'
WHERE P.CompanyID=@co AND P.PackageCode=@prefix+N'_DAY'
AND NOT EXISTS(SELECT 1 FROM dbo.TDSPPackageSport X WHERE X.CompanyID=@co AND X.PackageID=P.PackageID AND X.SportTypeID=S.SportTypeID);
COMMIT;
