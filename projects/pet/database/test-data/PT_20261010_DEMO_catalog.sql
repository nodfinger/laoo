-- Idempotent Pet acceptance fixture. All new rows are scoped to DEMO and PT_20261010_DEMO.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @run nvarchar(40)=N'PT_20261010_DEMO';
DECLARE @company bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@company AND Username=N'c111' AND IsActive=1);
DECLARE @branch bigint=(SELECT BranchID FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchCode=N'P110' AND IsActive=1);
DECLARE @member bigint=(SELECT MemberID FROM dbo.TDBKMember WHERE CompanyID=@company AND MemberCode=N'BK26_MEMBER' AND IsActive=1);
DECLARE @person bigint=(SELECT PersonID FROM dbo.TDBKMember WHERE CompanyID=@company AND MemberID=@member);
IF @company IS NULL OR @actor IS NULL OR @branch IS NULL OR @member IS NULL OR @person IS NULL
 THROW 62210,N'Pet catalog DEMO prerequisites are missing',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDARCustomer WHERE CompanyID=@company AND CusCode=N'PT26_OWNER')
 INSERT dbo.TDARCustomer(CompanyID,CusCode,CusName,Phone,IsActive,CreateBy)
 SELECT @company,N'PT26_OWNER',FullName,N'0000000000',1,@actor
 FROM dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@person;
DECLARE @owner bigint=(SELECT CustomerID FROM dbo.TDARCustomer WHERE CompanyID=@company AND CusCode=N'PT26_OWNER');
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKService WHERE CompanyID=@company AND ServiceCode=N'PT26_HOTEL')
 INSERT dbo.TDBKService(CompanyID,ServiceCode,ServiceName,DurationMinutes,Price,RequiresProvider,RequiresResource)
 VALUES(@company,N'PT26_HOTEL',N'โรงแรมสัตว์เลี้ยง [PT_20261010_DEMO]',1440,650,0,1);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKService WHERE CompanyID=@company AND ServiceCode=N'PT26_DAYCARE')
 INSERT dbo.TDBKService(CompanyID,ServiceCode,ServiceName,DurationMinutes,Price,RequiresProvider,RequiresResource)
 VALUES(@company,N'PT26_DAYCARE',N'ฝากเลี้ยงรายวัน [PT_20261010_DEMO]',480,300,0,1);
INSERT dbo.TDPTServiceMap(CompanyID,ServiceID,KindCode,UnitCode)
SELECT @company,B.ServiceID,V.Kind,V.Unit
FROM (VALUES
 (N'BK26_GROOM',N'GROOMING',N'VISIT'),
 (N'BK26_PICKUP',N'TRANSPORT',N'VISIT'),
 (N'PT26_HOTEL',N'HOTEL',N'NIGHT'),
 (N'PT26_DAYCARE',N'DAYCARE',N'DAY')) V(Code,Kind,Unit)
JOIN dbo.TDBKService B ON B.CompanyID=@company AND B.ServiceCode=V.Code AND B.IsActive=1
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDPTServiceMap M
 WHERE M.CompanyID=@company AND M.ServiceID=B.ServiceID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDBKResource WHERE CompanyID=@company
 AND ResourceName=N'ห้องพักสัตว์ A [PT_20261010_DEMO]')
 INSERT dbo.TDBKResource(CompanyID,BranchID,ResourceName,ResourceType)
 VALUES(@company,@branch,N'ห้องพักสัตว์ A [PT_20261010_DEMO]',N'PET_ROOM');
DECLARE @resource bigint=(SELECT ResourceID FROM dbo.TDBKResource
 WHERE CompanyID=@company AND ResourceName=N'ห้องพักสัตว์ A [PT_20261010_DEMO]');
IF NOT EXISTS(SELECT 1 FROM dbo.TDPTRoom WHERE CompanyID=@company AND RoomCode=N'PT26_ROOM_A')
 INSERT dbo.TDPTRoom(CompanyID,ResourceID,RoomCode,RoomName,Capacity)
 VALUES(@company,@resource,N'PT26_ROOM_A',N'ห้องพักสัตว์ A [PT_20261010_DEMO]',2);
IF NOT EXISTS(SELECT 1 FROM dbo.TDPTPet WHERE CompanyID=@company AND PetCode=N'PT26_MOCHI')
 INSERT dbo.TDPTPet(CompanyID,PetCode,OwnerCustomerID,MemberID,PetName,
  Species,Breed,SizeCode,CautionText,EmergencyName,EmergencyPhone)
 VALUES(@company,N'PT26_MOCHI',@owner,@member,N'โมจิ [PT_20261010_DEMO]',
  N'สุนัข',N'ปอมเมอเรเนียน',N'S',N'แพ้อาหารทะเล',N'เจ้าของตัวอย่าง',N'0000000000');
IF NOT EXISTS(SELECT 1 FROM dbo.TDPTPet WHERE CompanyID=@company AND PetCode=N'PT26_MALI')
 INSERT dbo.TDPTPet(CompanyID,PetCode,OwnerCustomerID,MemberID,PetName,
  Species,Breed,SizeCode,CautionText,EmergencyName,EmergencyPhone)
 VALUES(@company,N'PT26_MALI',@owner,@member,N'มะลิ [PT_20261010_DEMO]',
  N'แมว',N'ไทย',N'M',N'ต้องแยกจากสุนัข',N'เจ้าของตัวอย่าง',N'0000000000');
IF NOT EXISTS(SELECT 1 FROM dbo.TDPTPackage WHERE CompanyID=@company AND PackageCode=N'PT26_GROOM5')
 INSERT dbo.TDPTPackage(CompanyID,PackageCode,PackageName,Price,ValidDays,IncludedUnits,IsActive)
 VALUES(@company,N'PT26_GROOM5',N'อาบน้ำ 5 ครั้ง [PT_20261010_DEMO]',1200,180,5,1);
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDPTPackage
 WHERE CompanyID=@company AND PackageCode=N'PT26_GROOM5');
DECLARE @groom bigint=(SELECT ServiceID FROM dbo.TDBKService
 WHERE CompanyID=@company AND ServiceCode=N'BK26_GROOM');
IF NOT EXISTS(SELECT 1 FROM dbo.TDPTPackageService
 WHERE CompanyID=@company AND PackageID=@package AND ServiceID=@groom)
 INSERT dbo.TDPTPackageService(CompanyID,PackageID,ServiceID)
 VALUES(@company,@package,@groom);
INSERT dbo.TDPTAudit(CompanyID,EntityCode,EntityID,ActionCode,ActorID,DetailText)
VALUES(@company,N'TEST_FIXTURE',@package,N'SEED',@actor,@run);
COMMIT;
