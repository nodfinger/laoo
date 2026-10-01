SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @Run nvarchar(40)=N'SALES-20260930-C111';
DECLARE @Company bigint=(SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @User bigint=(SELECT UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
DECLARE @Employee bigint=(SELECT TOP 1 EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@Company AND UserID=@User AND IsActive=1);
DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES' AND IsActive=1);
DECLARE @Partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@Company AND IsActive=1);
DECLARE @AdminRole bigint=(SELECT TOP 1 RoleGroupID FROM dbo.TDADRoleGroup WHERE CompanyID=@Company AND RoleCode=N'ca' AND IsActive=1);
IF @Company IS NULL OR @User IS NULL OR @Employee IS NULL OR @Project IS NULL OR @Partner IS NULL OR @AdminRole IS NULL THROW 56320,N'c111 Sales fixture prerequisites are missing.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company)
 INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,CreateDate,CreatedBy) VALUES(@Project,@Partner,@Company,1,0,SYSUTCDATETIME(),@User);
ELSE UPDATE dbo.TDADCompanyProject SET IsEnabled=1,ExpireDate=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@User WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy) VALUES(@Company,@User,@Project,0,1,SYSUTCDATETIME(),@User);
ELSE UPDATE dbo.TDADUserProject SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@User WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project;

MERGE dbo.TDADRoleGroupPermission AS target
USING(SELECT @AdminRole RoleGroupID,ProjectID,ScreenCode MenuCode,ActionCode FROM dbo.TDADPermission WHERE ProjectID=@Project AND IsActive=1) source
ON target.RoleGroupID=source.RoleGroupID AND target.ProjectID=source.ProjectID AND target.MenuCode=source.MenuCode AND target.ActionCode=source.ActionCode
WHEN MATCHED THEN UPDATE SET IsAllowed=1,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=N'fixture'
WHEN NOT MATCHED THEN INSERT(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedUtc,CreatedBy) VALUES(source.RoleGroupID,source.ProjectID,source.MenuCode,source.ActionCode,1,SYSUTCDATETIME(),N'fixture');

IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemSales WHERE CompanyID=@Company AND ProjectID=@Project)
 INSERT dbo.TDSTCompanySetupSystemSales(CompanyID,ProjectID,IsEnabled,LeadIdleDays,ActivityReminderDays,CreateBy) VALUES(@Company,@Project,1,14,2,@User);

DECLARE @Stages table(Code nvarchar(30),Name nvarchar(150),SortOrder int,Probability decimal(5,2),Type nvarchar(10));
INSERT @Stages VALUES(N'NEW',N'เริ่มต้น',10,10,N'OPEN'),(N'QUALIFIED',N'ผ่านการคัดกรอง',20,30,N'OPEN'),(N'PROPOSAL',N'เสนอราคา',30,60,N'OPEN'),(N'NEGOTIATION',N'เจรจาต่อรอง',40,80,N'OPEN'),(N'WON',N'ปิดการขายสำเร็จ',90,100,N'WON'),(N'LOST',N'ปิดการขายไม่สำเร็จ',100,0,N'LOST');
INSERT dbo.TDSLPipelineStage(CompanyID,ProjectID,StageCode,StageName,SortOrder,ProbabilityPercent,StageType,CreateBy)
SELECT @Company,@Project,s.Code,s.Name,s.SortOrder,s.Probability,s.Type,@User FROM @Stages s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSLPipelineStage p WHERE p.CompanyID=@Company AND p.StageCode=s.Code);
UPDATE p SET StageName=s.Name,SortOrder=s.SortOrder,ProbabilityPercent=s.Probability,StageType=s.Type,IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
FROM dbo.TDSLPipelineStage p JOIN @Stages s ON s.Code=p.StageCode WHERE p.CompanyID=@Company AND p.ProjectID=@Project;
UPDATE dbo.TDSTCompanySetupSystemSales SET IsEnabled=1,DefaultStageID=(SELECT PipelineStageID FROM dbo.TDSLPipelineStage WHERE CompanyID=@Company AND StageCode=N'NEW'),WonStageID=(SELECT PipelineStageID FROM dbo.TDSLPipelineStage WHERE CompanyID=@Company AND StageCode=N'WON'),LostStageID=(SELECT PipelineStageID FROM dbo.TDSLPipelineStage WHERE CompanyID=@Company AND StageCode=N'LOST'),UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND ProjectID=@Project;

IF NOT EXISTS(SELECT 1 FROM dbo.TDSLLead WHERE CompanyID=@Company AND LeadCode=@Run+N'-LEAD')
 INSERT dbo.TDSLLead(CompanyID,ProjectID,LeadCode,LeadType,LeadName,ContactName,Phone,Email,SourceCode,ScoreValue,StatusCode,AssignedEmployeeID,LastContactAt,NextContactAt,Remark,CreateBy)
 VALUES(@Company,@Project,@Run+N'-LEAD',N'COMPANY',N'บริษัทตัวอย่าง Sales Flow',N'ผู้ประสานงานตัวอย่าง',N'0890000001',N'sales.fixture@laoo.test',N'REFERRAL',75,N'QUALIFIED',@Employee,DATEADD(day,-2,SYSUTCDATETIME()),DATEADD(day,2,SYSUTCDATETIME()),@Run,@User);
IF NOT EXISTS(SELECT 1 FROM dbo.TDSLLead WHERE CompanyID=@Company AND LeadCode=@Run+N'-CONVERT')
 INSERT dbo.TDSLLead(CompanyID,ProjectID,LeadCode,LeadType,LeadName,ContactName,Phone,Email,SourceCode,ScoreValue,StatusCode,AssignedEmployeeID,Remark,CreateBy)
 VALUES(@Company,@Project,@Run+N'-CONVERT',N'PERSON',N'ลูกค้าเป้าหมายสำหรับทดสอบ Convert',N'ผู้ทดสอบ Convert',N'0890000002',N'convert.fixture@laoo.test',N'WEBSITE',90,N'QUALIFIED',@Employee,@Run,@User);
UPDATE dbo.TDSLLead SET LeadName=N'บริษัทตัวอย่าง Sales Flow',ContactName=N'ผู้ประสานงานตัวอย่าง',UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND LeadCode=@Run+N'-LEAD';
UPDATE dbo.TDSLLead SET LeadName=N'ลูกค้าเป้าหมายสำหรับทดสอบ Convert',ContactName=N'ผู้ทดสอบ Convert',UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND LeadCode=@Run+N'-CONVERT';

DECLARE @Customer bigint=(SELECT TOP 1 CustomerID FROM dbo.TDARCustomer WHERE CompanyID=@Company AND IsActive=1 ORDER BY CustomerID);
DECLARE @Stage bigint=(SELECT PipelineStageID FROM dbo.TDSLPipelineStage WHERE CompanyID=@Company AND StageCode=N'PROPOSAL');
IF @Customer IS NULL THROW 56321,N'An active customer is required for Sales fixture.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDSLOpportunity WHERE CompanyID=@Company AND OpportunityCode=@Run+N'-OPP')
 INSERT dbo.TDSLOpportunity(CompanyID,ProjectID,OpportunityCode,OpportunityName,CustomerID,PipelineStageID,Amount,ProbabilityPercent,ExpectedCloseDate,AssignedEmployeeID,Remark,CreateBy)
 VALUES(@Company,@Project,@Run+N'-OPP',N'โอกาสขายจากข้อมูลลูกค้าจริง',@Customer,@Stage,125000,60,DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),@Employee,@Run,@User);
DECLARE @Lead bigint=(SELECT LeadID FROM dbo.TDSLLead WHERE CompanyID=@Company AND LeadCode=@Run+N'-LEAD');
DECLARE @Opportunity bigint=(SELECT OpportunityID FROM dbo.TDSLOpportunity WHERE CompanyID=@Company AND OpportunityCode=@Run+N'-OPP');
IF NOT EXISTS(SELECT 1 FROM dbo.TDSLActivity WHERE CompanyID=@Company AND ActivityCode=@Run+N'-OVERDUE')
 INSERT dbo.TDSLActivity(CompanyID,ProjectID,ActivityCode,ActivityType,Title,LeadID,AssignedEmployeeID,StartAt,DueAt,StatusCode,DescriptionText,CreateBy) VALUES(@Company,@Project,@Run+N'-OVERDUE',N'CALL',N'โทรติดตาม Lead ที่เกินกำหนด',@Lead,@Employee,DATEADD(day,-5,SYSUTCDATETIME()),DATEADD(day,-3,SYSUTCDATETIME()),N'PENDING',@Run,@User);
IF NOT EXISTS(SELECT 1 FROM dbo.TDSLActivity WHERE CompanyID=@Company AND ActivityCode=@Run+N'-NEXT')
 INSERT dbo.TDSLActivity(CompanyID,ProjectID,ActivityCode,ActivityType,Title,CustomerID,OpportunityID,AssignedEmployeeID,StartAt,DueAt,StatusCode,DescriptionText,CreateBy) VALUES(@Company,@Project,@Run+N'-NEXT',N'MEETING',N'นัดนำเสนอราคา',@Customer,@Opportunity,@Employee,DATEADD(day,1,SYSUTCDATETIME()),DATEADD(day,2,SYSUTCDATETIME()),N'PENDING',@Run,@User);
UPDATE dbo.TDSLActivity SET Title=N'โทรติดตาม Lead ที่เกินกำหนด',UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND ActivityCode=@Run+N'-OVERDUE';
UPDATE dbo.TDSLActivity SET Title=N'นัดนำเสนอราคา',UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND ActivityCode=@Run+N'-NEXT';
COMMIT TRANSACTION;
