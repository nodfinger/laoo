SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @Run nvarchar(40)=N'KNOWLEDGE-20261003-C111';
DECLARE @Company bigint=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @User bigint=(SELECT TOP 1 UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_KNOWLEDGE' AND IsActive=1);
DECLARE @Partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@Company AND IsActive=1);
DECLARE @Department bigint=(SELECT TOP 1 e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@Company AND ue.UserID=@User AND ue.IsActive=1 AND e.IsActive=1);
IF @Company IS NULL OR @User IS NULL OR @Project IS NULL OR @Partner IS NULL THROW 56920,N'c111 Knowledge fixture prerequisites are missing.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company)
 INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,CreateDate,CreatedBy) VALUES(@Project,@Partner,@Company,1,0,SYSUTCDATETIME(),@User);
ELSE UPDATE dbo.TDADCompanyProject SET IsEnabled=1,ExpireDate=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@User WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy) VALUES(@Company,@User,@Project,0,1,SYSUTCDATETIME(),@User);
ELSE UPDATE dbo.TDADUserProject SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@User WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project;
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @User,@Project,p.PermissionID,1,1,@Run,@User FROM dbo.TDADPermission p WHERE p.ProjectID=@Project AND p.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission x WHERE x.UserID=@User AND x.ProjectID=@Project AND x.PermissionID=p.PermissionID);
UPDATE up SET IsAllowed=1,IsActive=1,ModifiedDate=SYSUTCDATETIME(),ModifiedBy=@User FROM dbo.TDADUserPermission up JOIN dbo.TDADPermission p ON p.ProjectID=up.ProjectID AND p.PermissionID=up.PermissionID WHERE up.UserID=@User AND up.ProjectID=@Project AND p.IsActive=1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDKNSystemSetting WHERE CompanyID=@Company) INSERT dbo.TDKNSystemSetting(CompanyID,MaxVideoMB,MaxAttachmentMB,DefaultReviewMonths,CreateBy) VALUES(@Company,100,20,12,@User);
DECLARE @Categories TABLE(Code nvarchar(40),Name nvarchar(200),SortOrder int);
INSERT @Categories VALUES(N'POLICY',N'นโยบายและระเบียบ',10),(N'WORK',N'วิธีการทำงาน',20),(N'TECH',N'เทคโนโลยีและระบบ',30),(N'SERVICE',N'งานบริการลูกค้า',40),(N'SAFETY',N'ความปลอดภัย',50),(N'TRAINING',N'การอบรมและพัฒนา',60),(N'FAQ',N'คำถามที่พบบ่อย',70);
INSERT dbo.TDKNCategory(CompanyID,CategoryCode,CategoryName,OwnerUserID,SortOrder,CreateBy) SELECT @Company,c.Code,c.Name,@User,c.SortOrder,@User FROM @Categories c WHERE NOT EXISTS(SELECT 1 FROM dbo.TDKNCategory x WHERE x.CompanyID=@Company AND x.CategoryCode=c.Code);
UPDATE x SET CategoryName=c.Name,OwnerUserID=@User,SortOrder=c.SortOrder,IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME() FROM dbo.TDKNCategory x JOIN @Categories c ON c.Code=x.CategoryCode WHERE x.CompanyID=@Company;
INSERT dbo.TDKNCategoryExpert(CompanyID,CategoryID,UserID,CreateBy) SELECT @Company,CategoryID,@User,@User FROM dbo.TDKNCategory c WHERE c.CompanyID=@Company AND NOT EXISTS(SELECT 1 FROM dbo.TDKNCategoryExpert e WHERE e.CompanyID=@Company AND e.CategoryID=c.CategoryID AND e.UserID=@User);

DECLARE @Cases TABLE(Code nvarchar(80),Title nvarchar(500),Summary nvarchar(1000),Category nvarchar(40),ContentType nvarchar(30),Status nvarchar(30),Audience nvarchar(20),SourceUrl nvarchar(2000),ReviewOffset int);
INSERT @Cases VALUES
(@Run+N'-DRAFT',N'ร่างคู่มือการรับแจ้งงานบริการ',N'ตัวอย่างบทความที่เจ้าของกำลังจัดทำ',N'WORK',N'ARTICLE',N'DRAFT',N'RESTRICTED',NULL,180),
(@Run+N'-REVIEW',N'แนวทางตรวจสอบคุณภาพข้อมูลก่อนเผยแพร่',N'ตัวอย่างงานรอตรวจทาน',N'TECH',N'ARTICLE',N'IN_REVIEW',N'ALL',NULL,180),
(@Run+N'-PUBLISHED',N'คู่มือใช้งาน LAOO สำหรับผู้เริ่มต้น',N'ตัวอย่างบทความเผยแพร่สำหรับทุกคน',N'TECH',N'ARTICLE',N'PUBLISHED',N'ALL',NULL,180),
(@Run+N'-VIDEO',N'คลิปสาธิตขั้นตอนรับสินค้า',N'ตัวอย่างวิดีโอ URL ที่เปิดจากคลังความรู้',N'TRAINING',N'VIDEO_URL',N'PUBLISHED',N'ALL',N'https://example.com/training/video',180),
(@Run+N'-DOCUMENT',N'นโยบายความปลอดภัยฉบับควบคุม',N'อ้างอิงต้นฉบับจากระบบควบคุมเอกสารโดยไม่คัดลอกไฟล์',N'POLICY',N'DOCUMENT_CONTROL',N'PUBLISHED',N'RESTRICTED',N'/company/document-library',180),
(@Run+N'-TRAINING',N'หลักสูตรปฐมนิเทศพนักงานใหม่',N'อ้างอิงข้อมูลจากระบบอบรม',N'TRAINING',N'TRAINING',N'PUBLISHED',N'ALL',N'/company/training-courses',180),
(@Run+N'-DUE',N'ขั้นตอนตรวจพื้นที่ความปลอดภัย',N'บทความครบกำหนดทบทวน',N'SAFETY',N'ARTICLE',N'REVIEW_DUE',N'ALL',NULL,-1),
(@Run+N'-ARCHIVED',N'คู่มือระบบเวอร์ชันเดิม',N'ตัวอย่างเนื้อหาที่จัดเก็บแล้ว',N'TECH',N'ARTICLE',N'ARCHIVED',N'ALL',NULL,-365);
DECLARE @Code nvarchar(80),@Title nvarchar(500),@Summary nvarchar(1000),@Category nvarchar(40),@Type nvarchar(30),@Status nvarchar(30),@Audience nvarchar(20),@Url nvarchar(2000),@Offset int;
DECLARE fixture CURSOR LOCAL FAST_FORWARD FOR SELECT Code,Title,Summary,Category,ContentType,Status,Audience,SourceUrl,ReviewOffset FROM @Cases;
OPEN fixture;FETCH NEXT FROM fixture INTO @Code,@Title,@Summary,@Category,@Type,@Status,@Audience,@Url,@Offset;
WHILE @@FETCH_STATUS=0
BEGIN
 DECLARE @Article bigint=(SELECT ArticleID FROM dbo.TDKNArticle WHERE CompanyID=@Company AND ArticleCode=@Code);
 IF @Article IS NULL BEGIN INSERT dbo.TDKNArticle(CompanyID,ArticleCode,CategoryID,Title,SummaryText,ContentType,SourceSystem,SourceUrl,OwnerUserID,StatusCode,AudienceMode,PublishedAt,NextReviewDate,CreateBy) SELECT @Company,@Code,CategoryID,@Title,@Summary,@Type,CASE WHEN @Type=N'DOCUMENT_CONTROL' THEN N'DOCUMENT_CONTROL' WHEN @Type=N'TRAINING' THEN N'TRAINING' END,@Url,@User,@Status,@Audience,CASE WHEN @Status IN(N'PUBLISHED',N'REVIEW_DUE',N'ARCHIVED') THEN DATEADD(day,-30,SYSUTCDATETIME()) END,DATEADD(day,@Offset,CONVERT(date,SYSUTCDATETIME())),@User FROM dbo.TDKNCategory WHERE CompanyID=@Company AND CategoryCode=@Category;SET @Article=SCOPE_IDENTITY();END
 ELSE UPDATE dbo.TDKNArticle SET Title=@Title,SummaryText=@Summary,ContentType=@Type,StatusCode=@Status,AudienceMode=@Audience,SourceUrl=@Url,NextReviewDate=DATEADD(day,@Offset,CONVERT(date,SYSUTCDATETIME())),UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND ArticleID=@Article;
 DECLARE @Revision bigint=(SELECT TOP 1 RevisionID FROM dbo.TDKNArticleRevision WHERE CompanyID=@Company AND ArticleID=@Article ORDER BY RevisionNo DESC);
 IF @Revision IS NULL BEGIN INSERT dbo.TDKNArticleRevision(CompanyID,ArticleID,RevisionNo,BodyText,StatusCode,ReviewerUserID,SubmittedAt,ReviewedBy,ReviewedAt,CreateBy) VALUES(@Company,@Article,1,N'เนื้อหาตัวอย่างสำหรับ '+@Title,CASE WHEN @Status=N'REVIEW_DUE' THEN N'PUBLISHED' ELSE @Status END,@User,CASE WHEN @Status=N'IN_REVIEW' THEN DATEADD(day,-1,SYSUTCDATETIME()) END,CASE WHEN @Status IN(N'PUBLISHED',N'REVIEW_DUE',N'ARCHIVED') THEN @User END,CASE WHEN @Status IN(N'PUBLISHED',N'REVIEW_DUE',N'ARCHIVED') THEN DATEADD(day,-30,SYSUTCDATETIME()) END,@User);SET @Revision=SCOPE_IDENTITY();END
 UPDATE dbo.TDKNArticle SET CurrentRevisionID=@Revision WHERE CompanyID=@Company AND ArticleID=@Article;
 DELETE dbo.TDKNArticleAudience WHERE CompanyID=@Company AND ArticleID=@Article;
 IF @Audience=N'RESTRICTED' INSERT dbo.TDKNArticleAudience(CompanyID,ArticleID,SubjectType,SubjectID,CreateBy) VALUES(@Company,@Article,CASE WHEN @Department IS NULL THEN N'USER' ELSE N'DEPARTMENT' END,COALESCE(@Department,@User),@User);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDKNAudit WHERE CompanyID=@Company AND EntityType=N'ARTICLE' AND EntityID=@Article AND ActionCode=N'FIXTURE') INSERT dbo.TDKNAudit(CompanyID,EntityType,EntityID,ActionCode,DetailText,UserID) VALUES(@Company,N'ARTICLE',@Article,N'FIXTURE',@Run,@User);
 FETCH NEXT FROM fixture INTO @Code,@Title,@Summary,@Category,@Type,@Status,@Audience,@Url,@Offset;
END
CLOSE fixture;DEALLOCATE fixture;

DECLARE @Faq bigint=(SELECT CategoryID FROM dbo.TDKNCategory WHERE CompanyID=@Company AND CategoryCode=N'FAQ');
DECLARE @Question bigint=(SELECT QuestionID FROM dbo.TDKNQuestion WHERE CompanyID=@Company AND QuestionTitle=N'ทดสอบ Flow: ขอคำแนะนำการค้นหาคู่มือ');
IF @Question IS NULL BEGIN INSERT dbo.TDKNQuestion(CompanyID,CategoryID,QuestionTitle,QuestionText,AskedBy,StatusCode,AudienceMode) VALUES(@Company,@Faq,N'ทดสอบ Flow: ขอคำแนะนำการค้นหาคู่มือ',N'ควรค้นหาจากชื่อหรือหมวดความรู้ก่อน',@User,N'RESOLVED',N'ALL');SET @Question=SCOPE_IDENTITY();END
IF NOT EXISTS(SELECT 1 FROM dbo.TDKNAnswer WHERE CompanyID=@Company AND QuestionID=@Question) INSERT dbo.TDKNAnswer(CompanyID,QuestionID,AnswerText,AnsweredBy,IsAccepted) VALUES(@Company,@Question,N'ค้นหาจากคำสำคัญ แล้วกรองด้วยหมวดและประเภทเนื้อหา',@User,1);
DECLARE @Published bigint=(SELECT ArticleID FROM dbo.TDKNArticle WHERE CompanyID=@Company AND ArticleCode=@Run+N'-PUBLISHED');
IF NOT EXISTS(SELECT 1 FROM dbo.TDKNFeedback WHERE CompanyID=@Company AND ArticleID=@Published AND UserID=@User) INSERT dbo.TDKNFeedback(CompanyID,ArticleID,RevisionID,UserID,IsHelpful,CommentText) SELECT @Company,@Published,CurrentRevisionID,@User,1,N'ข้อมูลตัวอย่างมีประโยชน์' FROM dbo.TDKNArticle WHERE ArticleID=@Published;
IF NOT EXISTS(SELECT 1 FROM dbo.TDKNFollow WHERE CompanyID=@Company AND ArticleID=@Published AND UserID=@User) INSERT dbo.TDKNFollow(CompanyID,ArticleID,UserID) VALUES(@Company,@Published,@User);
COMMIT TRANSACTION;
