-- Idempotent SITE acceptance fixture for DEMO / c111 only.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @run nvarchar(40)=N'SI_20261010_DEMO';
DECLARE @today date=CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
DECLARE @company bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SITE' AND IsActive=1);
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@company AND Username=N'c111' AND IsActive=1);
DECLARE @ho bigint=(SELECT BranchID FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchCode=N'HO' AND IsActive=1);
DECLARE @p110 bigint=(SELECT BranchID FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchCode=N'P110' AND IsActive=1);
DECLARE @customer1 bigint=(SELECT TOP(1) CustomerID FROM dbo.TDARCustomer WHERE CompanyID=@company AND CusCode=N'69001' AND IsActive=1);
DECLARE @customer2 bigint=(SELECT TOP(1) CustomerID FROM dbo.TDARCustomer WHERE CompanyID=@company AND CusCode=N'69002' AND IsActive=1);
DECLARE @customer3 bigint=(SELECT TOP(1) CustomerID FROM dbo.TDARCustomer WHERE CompanyID=@company AND CusCode=N'69003' AND IsActive=1);
DECLARE @employee bigint=(SELECT TOP(1) EmployeeID FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1 ORDER BY EmployeeID);
DECLARE @item bigint=(SELECT TOP(1) ItemID FROM dbo.TDIVItem WHERE CompanyID=@company AND IsActive=1 ORDER BY ItemID);
IF @company IS NULL OR @partner IS NULL OR @project IS NULL OR @package IS NULL OR @actor IS NULL
 OR @ho IS NULL OR @p110 IS NULL OR @customer1 IS NULL OR @customer2 IS NULL OR @customer3 IS NULL
 OR @employee IS NULL OR @item IS NULL
 THROW 63201,N'SITE DEMO prerequisites missing',1;
IF EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription
 WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1 AND ISNULL(ReasonText,N'')<>@run)
 THROW 63202,N'Another current SITE subscription exists; do not overwrite',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@company AND ProjectID=@project AND IsCurrent=1)
BEGIN
 DECLARE @subscription bigint;
 INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText,CreateBy)
 VALUES(@partner,@company,@project,@package,N'TRIAL',@today,DATEADD(day,30,@today),1,@run,@actor);
 SET @subscription=SCOPE_IDENTITY();
 INSERT dbo.TDADCompanyProjectSubscriptionAudit(SubscriptionID,PartnerID,CompanyID,ProjectID,PackageID,ActionCode,BeforeJson,AfterJson,ReasonText,ActorType,ActorID)
 VALUES(@subscription,@partner,@company,@project,@package,N'ASSIGN',NULL,
 CONCAT(N'{"runId":"',@run,N'","status":"TRIAL"}'),@run,N'TEST_FIXTURE',@actor);
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
SELECT @actor,@project,P.PermissionID,1,1,@run,@actor
FROM dbo.TDADPermission P WHERE P.ProjectID=@project AND P.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U WHERE U.UserID=@actor AND U.ProjectID=@project AND U.PermissionID=P.PermissionID);
UPDATE dbo.TDADProjectMenu SET IsActive=1 WHERE ProjectID=@project AND MenuCode BETWEEN N'63001' AND N'63008';

INSERT dbo.TDSIProject(CompanyID,BranchID,CustomerID,ProjectCode,ProjectName,SiteAddress,Description,StartDate,DueDate,CreatedBy)
SELECT @company,V.BranchID,V.CustomerID,V.Code,V.Name,V.Address,@run,
 DATEADD(day,-10,@today),DATEADD(day,45,@today),@actor
FROM (VALUES
 (@p110,@customer2,N'SI26_CCTV',N'ติดตั้งกล้อง CCTV อาคารเรียน [SI_20261010_DEMO]',N'เพชรเกษม 110'),
 (@ho,@customer1,N'SI26_NETWORK',N'เดินระบบ Network สำนักงาน [SI_20261010_DEMO]',N'สำนักงานใหญ่'),
 (@ho,@customer3,N'SI26_BUILD',N'ปรับปรุงพื้นที่อาคาร [SI_20261010_DEMO]',N'สำนักงานใหญ่')
) V(BranchID,CustomerID,Code,Name,Address)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSIProject P WHERE P.CompanyID=@company AND P.ProjectCode=V.Code);

DECLARE @cctv bigint=(SELECT SiteProjectID FROM dbo.TDSIProject WHERE CompanyID=@company AND ProjectCode=N'SI26_CCTV');
DECLARE @network bigint=(SELECT SiteProjectID FROM dbo.TDSIProject WHERE CompanyID=@company AND ProjectCode=N'SI26_NETWORK');
DECLARE @build bigint=(SELECT SiteProjectID FROM dbo.TDSIProject WHERE CompanyID=@company AND ProjectCode=N'SI26_BUILD');
INSERT dbo.TDSITask(CompanyID,SiteProjectID,TaskName,Weight,ProgressPercent,SortOrder)
SELECT @company,V.ProjectID,V.Name,V.Weight,V.Progress,V.SortOrder
FROM (VALUES
 (@cctv,N'สำรวจจุดติดตั้ง',20.0,100.0,10),(@cctv,N'เดินสายและติดตั้งกล้อง',50.0,45.0,20),
 (@cctv,N'ทดสอบภาพและส่งมอบ',30.0,0.0,30),
 (@network,N'ออกแบบเครือข่าย',30.0,100.0,10),(@network,N'ติดตั้งอุปกรณ์',70.0,20.0,20),
 (@build,N'เตรียมพื้นที่',25.0,100.0,10),(@build,N'งานโครงสร้าง',75.0,10.0,20)
) V(ProjectID,Name,Weight,Progress,SortOrder)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSITask T WHERE T.CompanyID=@company AND T.SiteProjectID=V.ProjectID AND T.TaskName=V.Name);

IF NOT EXISTS(SELECT 1 FROM dbo.TDSIDailyReport WHERE CompanyID=@company AND SiteProjectID=@cctv AND Summary LIKE N'%SI_20261010_DEMO%')
BEGIN
 INSERT dbo.TDSIDailyReport(CompanyID,SiteProjectID,WorkDate,Summary,ProblemSummary,CreatedBy)
 VALUES(@company,@cctv,@today,N'ติดตั้งกล้องชุดแรก [SI_20261010_DEMO]',N'จุดติดตั้งด้านเหนือมีไฟไม่พอ',@actor);
 DECLARE @report bigint=SCOPE_IDENTITY();
 INSERT dbo.TDSIDailyLine(CompanyID,ReportID,LineType,EmployeeID,Description,Quantity,SortOrder)
 VALUES(@company,@report,N'WORKER',@employee,N'ช่างติดตั้ง CCTV',2,10);
 INSERT dbo.TDSIDailyLine(CompanyID,ReportID,LineType,ItemID,Description,Quantity,SortOrder)
 VALUES(@company,@report,N'MATERIAL',@item,N'วัสดุตัวอย่างจาก Master',3,20);
 INSERT dbo.TDSIDailyLine(CompanyID,ReportID,LineType,Description,Amount,SortOrder)
 VALUES(@company,@report,N'EXPENSE',N'ค่าเดินทางภายใน ไม่เผยแพร่',350,30);
 INSERT dbo.TDSIIssue(CompanyID,SiteProjectID,ReportID,Title,Detail,CreatedBy)
 VALUES(@company,@cctv,@report,N'ไฟฟ้าจุดติดตั้งไม่พอ [SI_20261010_DEMO]',N'ต้องประสานเพิ่มจุดจ่ายไฟ',@actor);
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDSIHandover WHERE CompanyID=@company AND SiteProjectID=@network AND StageName LIKE N'%SI_20261010_DEMO%')
 INSERT dbo.TDSIHandover(CompanyID,SiteProjectID,HandoverNo,StageName,HandoverType,Detail,CreatedBy)
 VALUES(@company,@network,N'SI-DEMO-HO-01',N'งวดออกแบบระบบ [SI_20261010_DEMO]',N'STAGE',N'แผนผังและรายการอุปกรณ์พร้อมส่งตรวจ',@actor);
INSERT dbo.TDSIAudit(CompanyID,SiteProjectID,EntityType,EntityID,ActionCode,ActorType,ActorID,DetailJson)
SELECT @company,@cctv,N'TEST_FIXTURE',@cctv,N'SEED',N'TEST_FIXTURE',@actor,CONCAT(N'{"runId":"',@run,N'"}')
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSIAudit WHERE CompanyID=@company AND EntityType=N'TEST_FIXTURE' AND EntityID=@cctv AND ActionCode=N'SEED');
COMMIT TRAN;
