-- DEMO-only fixture. Apply after both LAOO_DIGITAL_CHECKLIST migrations.
-- Run ID is recorded in subscription reason, permission remark, group codes and TDCLAudit.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @run nvarchar(40)=N'DCL_20261008_DEMO';
DECLARE @today date=CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_DIGITAL_CHECKLIST' AND IsActive=1);
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@co AND Username=N'c111' AND IsActive=1);
DECLARE @itDept bigint=(SELECT OrgUnitID FROM dbo.TDADOrganizationUnit WHERE CompanyID=@co AND UnitCode=N'IT' AND UnitType=N'DEP' AND IsActive=1);
IF @co IS NULL OR @partner IS NULL OR @project IS NULL OR @package IS NULL OR @actor IS NULL OR @itDept IS NULL
  THROW 58801,N'DEMO project, package, c111 or IT department is unavailable',1;
DECLARE @approver1 bigint, @approver2 bigint;
SELECT TOP(1) @approver1=U.UserID FROM dbo.TDADUser U
JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=U.CompanyID AND UE.UserID=U.UserID AND UE.IsActive=1
JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
JOIN dbo.TDADOrganizationUnit O ON O.CompanyID=E.CompanyID AND O.OrgUnitID=E.DepartmentOrgUnitID AND O.UnitType=N'DEP' AND O.IsActive=1
WHERE U.CompanyID=@co AND U.IsActive=1 AND U.UserID<>@actor AND E.DepartmentOrgUnitID<>@itDept
AND NOT EXISTS(SELECT 1 FROM dbo.TDADEmployeeOrganizationAssignment A WHERE A.CompanyID=@co AND A.EmployeeID=E.EmployeeID AND A.IsActive=1 AND A.EffectiveFrom<=@today AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=@today) AND ISNULL(A.DepartmentOrgUnitID,-1)<>E.DepartmentOrgUnitID)
ORDER BY U.UserID;
SELECT TOP(1) @approver2=U.UserID FROM dbo.TDADUser U
JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=U.CompanyID AND UE.UserID=U.UserID AND UE.IsActive=1
JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
JOIN dbo.TDADOrganizationUnit O ON O.CompanyID=E.CompanyID AND O.OrgUnitID=E.DepartmentOrgUnitID AND O.UnitType=N'DEP' AND O.IsActive=1
WHERE U.CompanyID=@co AND U.IsActive=1 AND U.UserID NOT IN(@actor,@approver1) AND E.DepartmentOrgUnitID<>@itDept
AND NOT EXISTS(SELECT 1 FROM dbo.TDADEmployeeOrganizationAssignment A WHERE A.CompanyID=@co AND A.EmployeeID=E.EmployeeID AND A.IsActive=1 AND A.EffectiveFrom<=@today AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=@today) AND ISNULL(A.DepartmentOrgUnitID,-1)<>E.DepartmentOrgUnitID)
ORDER BY U.UserID;
IF @approver1 IS NULL OR @approver2 IS NULL THROW 58802,N'Two active cross-department approvers are required',1;
IF EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1 AND ISNULL(ReasonText,N'')<>@run)
  THROW 58803,N'An unrelated subscription already owns this project',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1)
BEGIN
  INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,ReasonText,CreateBy)
  VALUES(@partner,@co,@project,@package,N'TRIAL',@today,DATEADD(day,30,@today),@run,@actor);
  INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
  SELECT @partner,@co,@project,1,1,@today,DATEADD(day,30,@today),@actor
  WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@project);
END;
INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
SELECT @partner,@co,@project,F.FeatureCode,1,1,@today,DATEADD(day,30,@today),@actor
FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=@package AND F.IsEnabled=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyFeature X WHERE X.CompanyID=@co AND X.ProjectID=@project AND X.FeatureCode=F.FeatureCode);
DECLARE @users TABLE(UserID bigint PRIMARY KEY,EmployeeID bigint NOT NULL,DepartmentID bigint NOT NULL);
INSERT @users(UserID,EmployeeID,DepartmentID)
SELECT U.UserID,UE.EmployeeID,E.DepartmentOrgUnitID FROM dbo.TDADUser U
JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=U.CompanyID AND UE.UserID=U.UserID AND UE.IsActive=1
JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
WHERE U.CompanyID=@co AND U.UserID IN(@actor,@approver1,@approver2);
IF (SELECT COUNT(*) FROM @users)<>3 OR NOT EXISTS(SELECT 1 FROM @users WHERE UserID=@actor AND DepartmentID=@itDept)
  THROW 58804,N'Test users do not map to the expected active employees/departments',1;
DECLARE @newAssignments TABLE(ID bigint PRIMARY KEY);
INSERT dbo.TDADEmployeeOrganizationAssignment(CompanyID,EmployeeID,DepartmentOrgUnitID,EffectiveFrom,IsActive,CreateBy)
OUTPUT INSERTED.EmployeeOrganizationAssignmentID INTO @newAssignments
SELECT @co,U.EmployeeID,U.DepartmentID,@today,1,@actor FROM @users U
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADEmployeeOrganizationAssignment A WHERE A.CompanyID=@co AND A.EmployeeID=U.EmployeeID AND A.DepartmentOrgUnitID=U.DepartmentID AND A.IsActive=1 AND A.EffectiveFrom<=@today AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=@today));
INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail)
SELECT @co,@actor,'SEED','EMPLOYEE_ASSIGNMENT',ID,@run FROM @newAssignments;
DECLARE @newUserProjects TABLE(ID bigint PRIMARY KEY);
INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
OUTPUT INSERTED.UserProjectID INTO @newUserProjects
SELECT @co,U.UserID,@project,0,1,SYSUTCDATETIME(),@actor FROM @users U
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject P WHERE P.CompanyID=@co AND P.UserID=U.UserID AND P.ProjectID=@project);
INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail)
SELECT @co,@actor,'SEED','USER_PROJECT',ID,@run FROM @newUserProjects;
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT U.UserID,@project,P.PermissionID,1,1,@run,@actor FROM @users U CROSS JOIN dbo.TDADPermission P
WHERE P.ProjectID=@project AND P.IsActive=1
AND (U.UserID=@actor OR (P.ScreenCode=N'58006' AND P.ActionCode=N'VIEW') OR (P.ScreenCode=N'58007' AND P.ActionCode IN(N'VIEW',N'APPROVE',N'RETURN')))
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission X WHERE X.UserID=U.UserID AND X.ProjectID=@project AND X.PermissionID=P.PermissionID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDCLSetting WHERE CompanyID=@co)
BEGIN
  INSERT dbo.TDCLSetting(CompanyID,ProjectID,TimeZoneId,NotifyInApp,NotifyEmail,ReminderMinutes)
  VALUES(@co,@project,N'Asia/Bangkok',1,0,60);
  INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail)
  VALUES(@co,@actor,'SEED','SETTING',@co,@run);
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDCLGroup WHERE CompanyID=@co AND GroupCode=@run+N'_IT')
  INSERT dbo.TDCLGroup(CompanyID,GroupCode,GroupName,DepartmentOrgUnitID)
  VALUES(@co,@run+N'_IT',N'งาน IT ตัวอย่าง',@itDept);
DECLARE @group bigint=(SELECT GroupID FROM dbo.TDCLGroup WHERE CompanyID=@co AND GroupCode=@run+N'_IT');
INSERT dbo.TDCLType(CompanyID,GroupID,TypeCode,TypeName)
SELECT @co,@group,V.Code,V.Name FROM (VALUES
  (@run+N'_CCTV',N'ตรวจกล้อง CCTV'),
  (@run+N'_BACKUP',N'ตรวจงานสำรองข้อมูล')) V(Code,Name)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDCLType T WHERE T.CompanyID=@co AND T.GroupID=@group AND T.TypeCode=V.Code);
DECLARE @cctv bigint=(SELECT TypeID FROM dbo.TDCLType WHERE CompanyID=@co AND GroupID=@group AND TypeCode=@run+N'_CCTV');
DECLARE @backup bigint=(SELECT TypeID FROM dbo.TDCLType WHERE CompanyID=@co AND GroupID=@group AND TypeCode=@run+N'_BACKUP');
INSERT dbo.TDCLTemplate(CompanyID,TypeID,TemplateCode,TemplateName)
SELECT @co,V.TypeID,V.Code,V.Name FROM (VALUES
  (@cctv,@run+N'_CCTV',N'แบบตรวจกล้องประจำวัน'),
  (@backup,@run+N'_BACKUP',N'แบบตรวจสำรองข้อมูล')) V(TypeID,Code,Name)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDCLTemplate T WHERE T.CompanyID=@co AND T.TemplateCode=V.Code);
DECLARE @cctvTemplate bigint=(SELECT TemplateID FROM dbo.TDCLTemplate WHERE CompanyID=@co AND TemplateCode=@run+N'_CCTV');
DECLARE @backupTemplate bigint=(SELECT TemplateID FROM dbo.TDCLTemplate WHERE CompanyID=@co AND TemplateCode=@run+N'_BACKUP');
INSERT dbo.TDCLTemplateItem(CompanyID,TemplateID,SequenceNo,ItemText,IsRequired)
SELECT @co,V.TemplateID,V.SequenceNo,V.ItemText,1 FROM (VALUES
  (@cctvTemplate,1,N'ภาพจากกล้องแสดงผลตามปกติ'),
  (@cctvTemplate,2,N'ระบบบันทึกภาพย้อนหลังได้'),
  (@backupTemplate,1,N'งานสำรองข้อมูลสำเร็จ'),
  (@backupTemplate,2,N'ทดสอบไฟล์สำรองแล้วเปิดได้')) V(TemplateID,SequenceNo,ItemText)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDCLTemplateItem I WHERE I.CompanyID=@co AND I.TemplateID=V.TemplateID AND I.SequenceNo=V.SequenceNo);
INSERT dbo.TDCLWorkflow(CompanyID,TypeID,WorkflowName)
SELECT @co,V.TypeID,V.Name FROM (VALUES
  (@cctv,@run+N'_CCTV_APPROVAL'),(@backup,@run+N'_BACKUP_APPROVAL')) V(TypeID,Name)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDCLWorkflow W WHERE W.CompanyID=@co AND W.TypeID=V.TypeID AND W.WorkflowName=V.Name);
INSERT dbo.TDCLWorkflowStep(CompanyID,WorkflowID,SequenceNo,ApproverUserID)
SELECT @co,W.WorkflowID,V.SequenceNo,V.UserID FROM dbo.TDCLWorkflow W
CROSS APPLY(VALUES(1,@approver1),(2,@approver2)) V(SequenceNo,UserID)
WHERE W.CompanyID=@co AND W.WorkflowName IN(@run+N'_CCTV_APPROVAL',@run+N'_BACKUP_APPROVAL')
AND NOT EXISTS(SELECT 1 FROM dbo.TDCLWorkflowStep X WHERE X.CompanyID=@co AND X.WorkflowID=W.WorkflowID AND X.SequenceNo=V.SequenceNo);
DECLARE @actorEmployee bigint=(SELECT EmployeeID FROM @users WHERE UserID=@actor);
INSERT dbo.TDCLSchedule(CompanyID,TypeID,TemplateID,WorkflowID,ScheduleName,FrequencyCode,TimesJson,WeekDaysJson,MonthDay,YearMonth,ResponsibleEmployeeID,StartsOn,EndsOn)
SELECT @co,V.TypeID,V.TemplateID,W.WorkflowID,V.Name,V.Frequency,V.Times,V.WeekDays,V.MonthDay,V.YearMonth,@actorEmployee,@today,DATEADD(day,30,@today)
FROM (VALUES
  (@cctv,@cctvTemplate,@run+N'_CCTV_DAILY',N'DAILY',N'["08:00","16:00"]',N'[1,2,3,4,5,6,7]',CAST(NULL AS int),CAST(NULL AS int)),
  (@backup,@backupTemplate,@run+N'_BACKUP_DAILY',N'DAILY',N'["21:00"]',N'[1,2,3,4,5,6,7]',CAST(NULL AS int),CAST(NULL AS int)),
  (@cctv,@cctvTemplate,@run+N'_CCTV_WEEKLY',N'WEEKLY',N'["09:00"]',N'[1,3,5]',CAST(NULL AS int),CAST(NULL AS int)),
  (@backup,@backupTemplate,@run+N'_BACKUP_MONTHLY',N'MONTHLY',N'["10:00"]',N'[1]',DAY(@today),CAST(NULL AS int)),
  (@backup,@backupTemplate,@run+N'_BACKUP_YEARLY',N'YEARLY',N'["11:00"]',N'[1]',DAY(@today),MONTH(@today))) V(TypeID,TemplateID,Name,Frequency,Times,WeekDays,MonthDay,YearMonth)
JOIN dbo.TDCLWorkflow W ON W.CompanyID=@co AND W.TypeID=V.TypeID AND W.IsActive=1
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDCLSchedule S WHERE S.CompanyID=@co AND S.ScheduleName=V.Name);
DECLARE @dailySchedule bigint=(SELECT ScheduleID FROM dbo.TDCLSchedule WHERE CompanyID=@co AND ScheduleName=@run+N'_CCTV_DAILY');
INSERT dbo.TDCLInspection(CompanyID,ScheduleID,TypeID,DepartmentOrgUnitID,InspectionCode,DueAt,StatusCode,CreatedBy)
SELECT @co,@dailySchedule,@cctv,@itDept,V.Code,DATEADD(minute,V.OffsetMinutes,SYSUTCDATETIME()),'DUE',@actor
FROM (VALUES(@run+N'_PASS',5),(@run+N'_FAIL',6),(@run+N'_NEGATIVE',7),(@run+N'_EVIDENCE',8)) V(Code,OffsetMinutes)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDCLInspection I WHERE I.CompanyID=@co AND I.InspectionCode=V.Code);
INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail)
SELECT @co,@actor,'SEED','GROUP',@group,@run WHERE NOT EXISTS(
  SELECT 1 FROM dbo.TDCLAudit A WHERE A.CompanyID=@co AND A.ActionCode='SEED' AND A.EntityCode='GROUP' AND A.EntityID=@group AND A.Detail=@run);
COMMIT;
SELECT @run RunID,@co CompanyID,@actor InspectorUserID,@approver1 FirstApproverUserID,@approver2 SecondApproverUserID,
  (SELECT COUNT(*) FROM dbo.TDCLSchedule WHERE CompanyID=@co AND ScheduleName LIKE @run+N'%') ScheduleCount,
  (SELECT COUNT(*) FROM dbo.TDCLInspection WHERE CompanyID=@co AND InspectionCode LIKE @run+N'%') DueSampleCount;
