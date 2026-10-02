SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @Run nvarchar(40)=N'DOCCTRL-20261002-C111';
DECLARE @Company bigint=(SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @User bigint=(SELECT UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_DOCUMENT' AND IsActive=1);
DECLARE @Partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@Company AND IsActive=1);
DECLARE @Department bigint=(SELECT TOP 1 e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@Company AND ue.UserID=@User AND ue.IsActive=1 AND e.IsActive=1);
DECLARE @AdminRole bigint=(SELECT TOP 1 RoleGroupID FROM dbo.TDADRoleGroup WHERE CompanyID=@Company AND IsActive=1 AND (RoleCode=N'ca' OR RoleCode=N'ADMIN' OR RoleNameTH LIKE N'%Admin%') ORDER BY CASE WHEN RoleCode=N'ca' THEN 0 ELSE 1 END);
IF @Company IS NULL OR @User IS NULL OR @Project IS NULL OR @Partner IS NULL OR @AdminRole IS NULL THROW 56820,N'c111 Document Control fixture prerequisites are missing.',1;

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

IF NOT EXISTS(SELECT 1 FROM dbo.TDDCSystemSetting WHERE CompanyID=@Company)
 INSERT dbo.TDDCSystemSetting(CompanyID,MaxPrimaryFileMB,MaxAttachmentFileMB,ReminderDays,CreateBy) VALUES(@Company,20,20,3,@User);

DECLARE @Types TABLE(Code nvarchar(30),Name nvarchar(200),Kind nvarchar(20),Ack bit,Audience nvarchar(20));
INSERT @Types VALUES
(N'POLICY',N'นโยบายบริษัท',N'CONTROLLED',1,N'ALL'),
(N'PROCEDURE',N'ระเบียบปฏิบัติงาน',N'CONTROLLED',1,N'RESTRICTED'),
(N'FORM',N'แบบฟอร์มควบคุม',N'CONTROLLED',0,N'ALL'),
(N'GENERAL',N'เอกสารทั่วไป',N'GENERAL',0,N'ALL');
INSERT dbo.TDDCDocumentType(CompanyID,TypeCode,TypeName,DocumentClass,RequireAcknowledgement,DefaultReviewerUserID,DefaultApproverUserID,DefaultAudienceMode,CreateBy)
SELECT @Company,x.Code,x.Name,x.Kind,x.Ack,@User,@User,x.Audience,@User FROM @Types x WHERE NOT EXISTS(SELECT 1 FROM dbo.TDDCDocumentType t WHERE t.CompanyID=@Company AND t.TypeCode=x.Code);
UPDATE t SET TypeName=x.Name,DocumentClass=x.Kind,RequireAcknowledgement=x.Ack,DefaultReviewerUserID=@User,DefaultApproverUserID=@User,DefaultAudienceMode=x.Audience,IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
FROM dbo.TDDCDocumentType t JOIN @Types x ON x.Code=t.TypeCode WHERE t.CompanyID=@Company;

DECLARE @Cases TABLE(No nvarchar(80),Title nvarchar(500),Kind nvarchar(20),TypeCode nvarchar(30),Status nvarchar(30),Revision nvarchar(30),Audience nvarchar(20),Ack bit);
INSERT @Cases VALUES
(@Run+N'-DRAFT',N'ระเบียบตัวอย่างสถานะร่าง',N'CONTROLLED',N'PROCEDURE',N'DRAFT',N'00',N'RESTRICTED',1),
(@Run+N'-REVIEW',N'ระเบียบตัวอย่างรอตรวจทาน',N'CONTROLLED',N'PROCEDURE',N'IN_REVIEW',N'01',N'ALL',1),
(@Run+N'-APPROVE',N'นโยบายตัวอย่างรออนุมัติ',N'CONTROLLED',N'POLICY',N'IN_APPROVAL',N'02',N'ALL',1),
(@Run+N'-EFFECTIVE',N'นโยบายความปลอดภัยที่มีผลบังคับใช้',N'CONTROLLED',N'POLICY',N'EFFECTIVE',N'03',N'ALL',1),
(@Run+N'-OBSOLETE',N'แบบฟอร์มที่ยกเลิกใช้',N'CONTROLLED',N'FORM',N'OBSOLETE',N'01',N'ALL',0),
(@Run+N'-GENERAL',N'คู่มือสวัสดิการพนักงาน',N'GENERAL',N'GENERAL',N'PUBLISHED',N'01',N'ALL',0);

DECLARE @No nvarchar(80),@Title nvarchar(500),@Kind nvarchar(20),@TypeCode nvarchar(30),@Status nvarchar(30),@Revision nvarchar(30),@Audience nvarchar(20),@Ack bit;
DECLARE fixture CURSOR LOCAL FAST_FORWARD FOR SELECT No,Title,Kind,TypeCode,Status,Revision,Audience,Ack FROM @Cases;
OPEN fixture; FETCH NEXT FROM fixture INTO @No,@Title,@Kind,@TypeCode,@Status,@Revision,@Audience,@Ack;
WHILE @@FETCH_STATUS=0
BEGIN
 DECLARE @Document bigint=(SELECT DocumentID FROM dbo.TDDCDocument WHERE CompanyID=@Company AND DocumentNo=@No);
 IF @Document IS NULL
 BEGIN
  INSERT dbo.TDDCDocument(CompanyID,DocumentTypeID,DocumentNo,DocumentTitle,DocumentClass,OwnerDepartmentID,OwnerUserID,StatusCode,AudienceMode,RequireAcknowledgement,PublishDate,CreateBy)
  SELECT @Company,DocumentTypeID,@No,@Title,@Kind,@Department,@User,@Status,@Audience,@Ack,CASE WHEN @Kind=N'GENERAL' THEN SYSUTCDATETIME() END,@User FROM dbo.TDDCDocumentType WHERE CompanyID=@Company AND TypeCode=@TypeCode;
  SET @Document=SCOPE_IDENTITY();
 END
 ELSE UPDATE dbo.TDDCDocument SET DocumentTitle=@Title,StatusCode=@Status,AudienceMode=@Audience,RequireAcknowledgement=@Ack,UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND DocumentID=@Document;
 DECLARE @RevisionID bigint=(SELECT RevisionID FROM dbo.TDDCRevision WHERE CompanyID=@Company AND DocumentID=@Document AND RevisionNo=@Revision);
 IF @RevisionID IS NULL
 BEGIN
  INSERT dbo.TDDCRevision(CompanyID,DocumentID,RevisionNo,ChangeSummary,EffectiveDate,StatusCode,ReviewerUserID,ApproverUserID,ReviewedBy,ReviewedDate,ApprovedBy,ApprovedDate,CreateBy)
  VALUES(@Company,@Document,@Revision,@Run,CASE WHEN @Status IN(N'EFFECTIVE',N'OBSOLETE') THEN DATEADD(day,-30,CONVERT(date,SYSUTCDATETIME())) END,CASE WHEN @Status=N'PUBLISHED' THEN N'EFFECTIVE' ELSE @Status END,@User,@User,CASE WHEN @Status IN(N'IN_APPROVAL',N'EFFECTIVE',N'OBSOLETE') THEN @User END,CASE WHEN @Status IN(N'IN_APPROVAL',N'EFFECTIVE',N'OBSOLETE') THEN DATEADD(day,-2,SYSUTCDATETIME()) END,CASE WHEN @Status IN(N'EFFECTIVE',N'OBSOLETE') THEN @User END,CASE WHEN @Status IN(N'EFFECTIVE',N'OBSOLETE') THEN DATEADD(day,-1,SYSUTCDATETIME()) END,@User);
  SET @RevisionID=SCOPE_IDENTITY();
 END
 UPDATE dbo.TDDCDocument SET CurrentRevisionID=@RevisionID WHERE CompanyID=@Company AND DocumentID=@Document;
 DELETE dbo.TDDCAccessRule WHERE CompanyID=@Company AND DocumentID=@Document;
 IF @Audience=N'ALL' INSERT dbo.TDDCAccessRule(CompanyID,DocumentID,SubjectType,CanView,CanPreview,CanDownload,CreateBy) VALUES(@Company,@Document,N'ALL',1,1,1,@User);
 ELSE IF @Department IS NOT NULL INSERT dbo.TDDCAccessRule(CompanyID,DocumentID,SubjectType,SubjectID,CanView,CanPreview,CanDownload,CreateBy) VALUES(@Company,@Document,N'DEPARTMENT',@Department,1,1,0,@User);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDDCAudit WHERE CompanyID=@Company AND DocumentID=@Document AND ActionCode=N'FIXTURE')
  INSERT dbo.TDDCAudit(CompanyID,DocumentID,RevisionID,ActionCode,DetailText,UserID) VALUES(@Company,@Document,@RevisionID,N'FIXTURE',@Run,@User);
 FETCH NEXT FROM fixture INTO @No,@Title,@Kind,@TypeCode,@Status,@Revision,@Audience,@Ack;
END
CLOSE fixture; DEALLOCATE fixture;
COMMIT TRANSACTION;
