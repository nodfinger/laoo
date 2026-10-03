SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @Run nvarchar(50)=N'PROVIDER-20261003-C111';
DECLARE @Company bigint=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @User bigint=(SELECT TOP 1 UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
IF @Company IS NULL OR @User IS NULL THROW 57131,N'c111 provider fixture prerequisites are missing.',1;

DECLARE @Locations TABLE(Code nvarchar(20),Type nvarchar(20),ParentCode nvarchar(20),Name nvarchar(200),Lat decimal(10,7),Lng decimal(10,7),Sort int);
INSERT @Locations VALUES
(N'10',N'PROVINCE',NULL,N'กรุงเทพมหานคร',13.7563000,100.5018000,10),
(N'1001',N'DISTRICT',N'10',N'พระนคร',13.7566000,100.5010000,10),
(N'100101',N'SUBDISTRICT',N'1001',N'พระบรมมหาราชวัง',13.7518000,100.4925000,10),
(N'12',N'PROVINCE',NULL,N'นนทบุรี',13.8591000,100.5217000,20),
(N'1201',N'DISTRICT',N'12',N'เมืองนนทบุรี',13.8621000,100.5144000,10),
(N'120101',N'SUBDISTRICT',N'1201',N'สวนใหญ่',13.8457000,100.4966000,10),
(N'83',N'PROVINCE',NULL,N'ภูเก็ต',7.8804000,98.3923000,30),
(N'8301',N'DISTRICT',N'83',N'เมืองภูเก็ต',7.8881000,98.3978000,10),
(N'830101',N'SUBDISTRICT',N'8301',N'ตลาดใหญ่',7.8840000,98.3910000,10);
DECLARE @Level int=1;
WHILE @Level<=3
BEGIN
 INSERT dbo.TDPRLocation(LocationCode,LocationType,ParentLocationID,NameTH,Latitude,Longitude,SortOrder,IsActive,CreateBy)
 SELECT s.Code,s.Type,p.LocationID,s.Name,s.Lat,s.Lng,s.Sort,1,@User FROM @Locations s LEFT JOIN dbo.TDPRLocation p ON p.LocationCode=s.ParentCode
 WHERE (CASE s.Type WHEN N'PROVINCE' THEN 1 WHEN N'DISTRICT' THEN 2 ELSE 3 END)=@Level AND NOT EXISTS(SELECT 1 FROM dbo.TDPRLocation x WHERE x.LocationCode=s.Code);
 UPDATE x SET NameTH=s.Name,Latitude=s.Lat,Longitude=s.Lng,SortOrder=s.Sort,IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME() FROM dbo.TDPRLocation x JOIN @Locations s ON s.Code=x.LocationCode;
 SET @Level+=1;
END

DECLARE @Services TABLE(Code nvarchar(40),Name nvarchar(200),Description nvarchar(1000),Icon nvarchar(100),Sort int);
INSERT @Services VALUES
(N'ELECTRIC',N'ช่างไฟฟ้า',N'ติดตั้ง ตรวจสอบ และซ่อมระบบไฟฟ้า',N'electrical_services_outlined',10),
(N'PLUMBING',N'ช่างประปา',N'แก้ท่อรั่ว ท่อตัน และติดตั้งระบบประปา',N'plumbing_outlined',20),
(N'CCTV',N'ช่าง CCTV',N'ติดตั้งและบำรุงรักษากล้องวงจรปิด',N'videocam_outlined',30);
INSERT dbo.TDPRServiceType(ServiceCode,ServiceName,DescriptionText,IconName,SortOrder,IsActive,CreateBy)
SELECT Code,Name,Description,Icon,Sort,1,@User FROM @Services s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDPRServiceType x WHERE x.ServiceCode=s.Code);
UPDATE x SET ServiceName=s.Name,DescriptionText=s.Description,IconName=s.Icon,SortOrder=s.Sort,IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME() FROM dbo.TDPRServiceType x JOIN @Services s ON s.Code=x.ServiceCode;
UPDATE dbo.TDPRServiceType
SET CoverImagePath=CONCAT(N'uploads/provider/service-types/',ServiceTypeID,N'/sample-cover.png'),
    CoverMimeType=N'image/png',CoverSizeBytes=86649,UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
WHERE ServiceCode IN(N'ELECTRIC',N'PLUMBING',N'CCTV');

IF NOT EXISTS(SELECT 1 FROM dbo.TDPRSystemSetting WHERE CompanyID=@Company) INSERT dbo.TDPRSystemSetting(CompanyID,ServiceCoverMaxMB,ReviewExpiryDays,BayesianMinimumReviews,CreateBy) VALUES(@Company,2,30,5,@User);
DECLARE @Provider bigint=(SELECT ProviderID FROM dbo.TDPRProviderProfile WHERE CompanyID=@Company);
IF @Provider IS NULL BEGIN INSERT dbo.TDPRProviderProfile(CompanyID,Slug,StatusCode,CreateBy) VALUES(@Company,N'c111-smart-service',N'DRAFT',@User);SET @Provider=SCOPE_IDENTITY();END
DECLARE @Revision bigint=(SELECT RevisionID FROM dbo.TDPRProviderRevision WHERE ProviderID=@Provider AND RevisionNo=1);
IF @Revision IS NULL BEGIN INSERT dbo.TDPRProviderRevision(ProviderID,CompanyID,RevisionNo,DisplayName,SummaryText,PublicAddress,PublicTelephone,PublicEmail,LineID,LineUrl,WebsiteUrl,StatusCode,CreateBy) SELECT @Provider,@Company,1,COALESCE(CustomerNameTH,CustomerNameEN,N'C111 Smart Service'),N'ทีมช่างไฟฟ้า ประปา และ CCTV พร้อมให้บริการหลายพื้นที่',COALESCE(AddressText,N'กรุงเทพมหานคร'),COALESCE(Telephone,N'02-000-1111'),COALESCE(EmailAdmin,N'service@example.com'),N'@c111service',N'https://line.me/R/ti/p/@c111service',N'https://example.com',N'APPROVED',@User FROM dbo.TDSTCompanySetUp WHERE CompanyID=@Company;SET @Revision=SCOPE_IDENTITY();END
DELETE dbo.TDPRProviderService WHERE RevisionID=@Revision;
INSERT dbo.TDPRProviderService(CompanyID,RevisionID,ServiceTypeID,CreateBy) SELECT @Company,@Revision,ServiceTypeID,@User FROM dbo.TDPRServiceType WHERE ServiceCode IN(N'ELECTRIC',N'PLUMBING',N'CCTV');
DELETE dbo.TDPRProviderArea WHERE RevisionID=@Revision;
INSERT dbo.TDPRProviderArea(CompanyID,RevisionID,LocationID,CreateBy) SELECT @Company,@Revision,LocationID,@User FROM dbo.TDPRLocation WHERE LocationCode IN(N'10',N'12');
IF NOT EXISTS(SELECT 1 FROM dbo.TDPRProviderBranch WHERE RevisionID=@Revision) INSERT dbo.TDPRProviderBranch(CompanyID,RevisionID,BranchName,AddressText,Telephone,Latitude,Longitude,IsPrimary,CreateBy) VALUES(@Company,@Revision,N'สาขากรุงเทพฯ',N'เขตพระนคร กรุงเทพมหานคร',N'02-000-1111',13.7566000,100.5010000,1,@User);
UPDATE dbo.TDPRProviderProfile SET StatusCode=N'APPROVED',CurrentRevisionID=@Revision,PublishedRevisionID=@Revision,SubmittedAt=DATEADD(day,-30,SYSUTCDATETIME()),ApprovedBy=@User,ApprovedAt=DATEADD(day,-29,SYSUTCDATETIME()),IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE ProviderID=@Provider;

DECLARE @Service bigint=(SELECT ServiceTypeID FROM dbo.TDPRServiceType WHERE ServiceCode=N'ELECTRIC');
DECLARE @i int=1;
WHILE @i<=6
BEGIN
 DECLARE @Hash char(64)=CONVERT(varchar(64),HASHBYTES('SHA2_256',CONCAT(@Run,N'-',@i)),2);
 DECLARE @Invite bigint=(SELECT ReviewInviteID FROM dbo.TDPRReviewInvite WHERE TokenHash=@Hash);
 IF @Invite IS NULL BEGIN INSERT dbo.TDPRReviewInvite(CompanyID,ProviderID,ServiceTypeID,TokenHash,ServiceDate,ReferenceNo,ExpiresAt,StatusCode,UsedAt,CreateBy) VALUES(@Company,@Provider,@Service,@Hash,DATEADD(day,-@i,CONVERT(date,SYSUTCDATETIME())),CONCAT(@Run,N'-',@i),DATEADD(day,30,SYSUTCDATETIME()),N'USED',SYSUTCDATETIME(),@User);SET @Invite=SCOPE_IDENTITY();END
 IF NOT EXISTS(SELECT 1 FROM dbo.TDPRReview WHERE ReviewInviteID=@Invite) INSERT dbo.TDPRReview(CompanyID,ProviderID,ReviewInviteID,ServiceTypeID,QualityScore,PunctualityScore,ServiceScore,ValueScore,CommentText) VALUES(@Company,@Provider,@Invite,@Service,CASE WHEN @i=1 THEN 4 ELSE 5 END,4,5,4,N'บริการดี ติดต่อรวดเร็ว');
 SET @i+=1;
END
IF NOT EXISTS(SELECT 1 FROM dbo.TDPRAudit WHERE CompanyID=@Company AND EntityType=N'FIXTURE' AND DetailText=@Run) INSERT dbo.TDPRAudit(CompanyID,EntityType,EntityID,ActionCode,DetailText,UserID) VALUES(@Company,N'FIXTURE',@Provider,N'CREATE',@Run,@User);

DECLARE @UploadRoot nvarchar(1000)=CONCAT(N'uploads/provider/companies/',@Company,N'/');
UPDATE dbo.TDSTCompanySetUp
SET MemberCoverImagePath=CONCAT(@UploadRoot,N'member-cover.png'),
    MemberCoverMimeType=N'image/png',MemberCoverSizeBytes=86649,
    UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@Company AND OwnerType=N'C';

DECLARE @ElectricPortfolio bigint=(SELECT PortfolioID FROM dbo.TDPRPortfolio WHERE CompanyID=@Company AND WorkTitle=N'ติดตั้งระบบไฟฟ้าสำนักงานตัวอย่าง');
IF @ElectricPortfolio IS NULL
BEGIN
 INSERT dbo.TDPRPortfolio(CompanyID,WorkTitle,ServiceDate,CoverImagePath,CoverMimeType,CoverSizeBytes,IsActive,CreateBy)
 VALUES(@Company,N'ติดตั้งระบบไฟฟ้าสำนักงานตัวอย่าง',DATEADD(day,-25,CONVERT(date,SYSUTCDATETIME())),CONCAT(@UploadRoot,N'portfolio/sample-electric/cover.png'),N'image/png',86649,1,@User);
 SET @ElectricPortfolio=SCOPE_IDENTITY();
END
IF NOT EXISTS(SELECT 1 FROM dbo.TDPRPortfolioImage WHERE PortfolioID=@ElectricPortfolio AND SortOrder=1)
 INSERT dbo.TDPRPortfolioImage(PortfolioID,CompanyID,ImagePath,MimeType,SizeBytes,SortOrder,CreateBy)
 VALUES(@ElectricPortfolio,@Company,CONCAT(@UploadRoot,N'portfolio/sample-electric/photo-1.png'),N'image/png',46394,1,@User);

DECLARE @CctvPortfolio bigint=(SELECT PortfolioID FROM dbo.TDPRPortfolio WHERE CompanyID=@Company AND WorkTitle=N'ติดตั้งกล้อง CCTV อาคารตัวอย่าง');
IF @CctvPortfolio IS NULL
BEGIN
 INSERT dbo.TDPRPortfolio(CompanyID,WorkTitle,ServiceDate,CoverImagePath,CoverMimeType,CoverSizeBytes,IsActive,CreateBy)
 VALUES(@Company,N'ติดตั้งกล้อง CCTV อาคารตัวอย่าง',DATEADD(day,-12,CONVERT(date,SYSUTCDATETIME())),CONCAT(@UploadRoot,N'portfolio/sample-cctv/cover.png'),N'image/png',46394,1,@User);
 SET @CctvPortfolio=SCOPE_IDENTITY();
END
IF NOT EXISTS(SELECT 1 FROM dbo.TDPRPortfolioImage WHERE PortfolioID=@CctvPortfolio AND SortOrder=1)
 INSERT dbo.TDPRPortfolioImage(PortfolioID,CompanyID,ImagePath,MimeType,SizeBytes,SortOrder,CreateBy)
 VALUES(@CctvPortfolio,@Company,CONCAT(@UploadRoot,N'portfolio/sample-cctv/photo-1.png'),N'image/png',86649,1,@User);
IF NOT EXISTS(SELECT 1 FROM dbo.TDPRPortfolioImage WHERE PortfolioID=@CctvPortfolio AND SortOrder=2)
 INSERT dbo.TDPRPortfolioImage(PortfolioID,CompanyID,ImagePath,MimeType,SizeBytes,SortOrder,CreateBy)
 VALUES(@CctvPortfolio,@Company,CONCAT(@UploadRoot,N'portfolio/sample-cctv/photo-2.png'),N'image/png',46394,2,@User);
COMMIT;
