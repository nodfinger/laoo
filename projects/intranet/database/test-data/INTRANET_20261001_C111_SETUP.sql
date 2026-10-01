SET NOCOUNT ON;
DECLARE @CompanyID bigint=(SELECT TOP(1) CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @UserID bigint=(SELECT TOP(1) UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@CompanyID AND IsActive=1);
DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_INTRANET' AND IsActive=1);
DECLARE @PartnerID bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@CompanyID);
IF @CompanyID IS NULL OR @UserID IS NULL OR @ProjectID IS NULL THROW 54301,N'INTRANET_TEST_20261001 prerequisites are missing.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@CompanyID AND ProjectID=@ProjectID)
 INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,StartDate,CreatedBy)
 VALUES(@ProjectID,@PartnerID,@CompanyID,1,0,CONVERT(date,SYSUTCDATETIME()),@UserID);
ELSE
 UPDATE dbo.TDADCompanyProject SET IsEnabled=1,ExpireDate=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@UserID
 WHERE CompanyID=@CompanyID AND ProjectID=@ProjectID;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@CompanyID AND UserID=@UserID AND ProjectID=@ProjectID)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateBy)
 VALUES(@CompanyID,@UserID,@ProjectID,0,1,@UserID);
ELSE
 UPDATE dbo.TDADUserProject SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
 WHERE CompanyID=@CompanyID AND UserID=@UserID AND ProjectID=@ProjectID;

INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @UserID,@ProjectID,p.PermissionID,1,1,N'INTRANET_TEST_20261001',@UserID
FROM dbo.TDADPermission p
WHERE p.ProjectID=@ProjectID AND p.IsActive=1
 AND NOT EXISTS(
  SELECT 1 FROM dbo.TDADUserPermission x
  WHERE x.UserID=@UserID AND x.ProjectID=@ProjectID AND x.PermissionID=p.PermissionID
 );
UPDATE up SET IsAllowed=1,IsActive=1,ModifiedDate=SYSUTCDATETIME(),ModifiedBy=@UserID
FROM dbo.TDADUserPermission up
JOIN dbo.TDADPermission p ON p.ProjectID=up.ProjectID AND p.PermissionID=up.PermissionID
WHERE up.UserID=@UserID AND up.ProjectID=@ProjectID AND p.IsActive=1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemIntranet WHERE CompanyID=@CompanyID)
 INSERT dbo.TDSTCompanySetupSystemIntranet(CompanyID,ProjectID,RequireApproval,AllowSelfApproval,CreateBy)
 VALUES(@CompanyID,@ProjectID,1,1,@UserID);

DECLARE @Data TABLE(Code nvarchar(40),TypeCode nvarchar(20),Title nvarchar(250),SummaryText nvarchar(1000),Pinned bit,Ack bit,DaysOffset int);
INSERT @Data VALUES
(N'INTRANET_TEST_20261001_HOLIDAY',N'ANNOUNCEMENT',N'ประกาศวันหยุดประจำปี 2570',N'ประกาศวันหยุดและวันหยุดชดเชยสำหรับการวางแผนงานล่วงหน้า',1,0,30),
(N'INTRANET_TEST_20261001_PRIVACY',N'DOCUMENT',N'นโยบายคุ้มครองข้อมูลส่วนบุคคล',N'กรุณาอ่านและยืนยันการรับทราบภายในเวลาที่กำหนด',1,1,14),
(N'INTRANET_TEST_20261001_TOWNHALL',N'ACTIVITY',N'Town Hall ประจำไตรมาส 4',N'พบผู้บริหารและร่วมถามตอบ ถ่ายทอดสดสำหรับสาขาต่างจังหวัด',0,0,10),
(N'INTRANET_TEST_20261001_EXPENSE',N'NEWS',N'เปิดใช้งานระบบเบิกค่าใช้จ่ายรูปแบบใหม่',N'ส่งเอกสารและติดตามสถานะได้สะดวกผ่าน LAOO Platform',0,0,45);

INSERT dbo.TDINContent(CompanyID,ProjectID,ContentCode,ContentTypeCode,Title,SummaryText,BodyText,TargetMode,IsPinned,RequiresAcknowledgement,PublishAt,ExpireAt,StatusCode,ApprovedAt,PublishedAt,CreateBy)
SELECT @CompanyID,@ProjectID,d.Code,d.TypeCode,d.Title,d.SummaryText,d.SummaryText,N'ALL',d.Pinned,d.Ack,DATEADD(day,-1,SYSUTCDATETIME()),DATEADD(day,d.DaysOffset,SYSUTCDATETIME()),N'PUBLISHED',SYSUTCDATETIME(),SYSUTCDATETIME(),@UserID
FROM @Data d WHERE NOT EXISTS(SELECT 1 FROM dbo.TDINContent c WHERE c.CompanyID=@CompanyID AND c.ContentCode=d.Code);
