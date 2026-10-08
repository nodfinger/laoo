-- Remove only the DCL_20261008_DEMO fixture. Refuse cleanup after external handoff or file upload.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @run nvarchar(40)=N'DCL_20261008_DEMO';
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO');
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_DIGITAL_CHECKLIST');
DECLARE @group bigint=(SELECT GroupID FROM dbo.TDCLGroup WHERE CompanyID=@co AND GroupCode=@run+N'_IT');
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@co AND Username=N'c111');
IF @co IS NULL OR @project IS NULL OR @group IS NULL OR @actor IS NULL
  THROW 58820,N'The exact DEMO fixture is not present',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDCLAudit WHERE CompanyID=@co AND ActionCode='SEED' AND EntityCode='GROUP' AND EntityID=@group AND Detail=@run)
  THROW 58821,N'Fixture ownership marker is missing',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND ReasonText=@run)
  THROW 58822,N'Subscription belongs to another run',1;
DECLARE @types TABLE(ID bigint PRIMARY KEY);
INSERT @types SELECT TypeID FROM dbo.TDCLType WHERE CompanyID=@co AND GroupID=@group;
IF EXISTS(SELECT 1 FROM dbo.TDCLInspection I JOIN @types T ON T.ID=I.TypeID WHERE I.CompanyID=@co AND I.CreatedBy<>@actor)
  THROW 58823,N'Another user has inspections in the sample group; review them manually',1;
IF EXISTS(SELECT 1 FROM dbo.TDCLSchedule S JOIN @types T ON T.ID=S.TypeID WHERE S.CompanyID=@co AND S.ScheduleName NOT LIKE @run+N'%')
  THROW 58824,N'An untagged schedule uses the sample group',1;
IF EXISTS(SELECT 1 FROM dbo.TDCLAttachment A JOIN dbo.TDCLInspection I ON I.CompanyID=A.CompanyID AND I.InspectionID=A.InspectionID JOIN @types T ON T.ID=I.TypeID WHERE A.CompanyID=@co)
  THROW 58825,N'Uploaded evidence files require an explicit file cleanup',1;
IF EXISTS(SELECT 1 FROM dbo.TDCLCorrectiveTask C JOIN dbo.TDCLInspection I ON I.CompanyID=C.CompanyID AND I.InspectionID=C.InspectionID JOIN @types T ON T.ID=I.TypeID WHERE C.CompanyID=@co AND C.ServiceTicketID IS NOT NULL)
  THROW 58826,N'Linked service requests must be preserved',1;
DECLARE @inspections TABLE(ID bigint PRIMARY KEY);
INSERT @inspections SELECT I.InspectionID FROM dbo.TDCLInspection I JOIN @types T ON T.ID=I.TypeID WHERE I.CompanyID=@co;
DECLARE @tasks TABLE(ID bigint PRIMARY KEY);
INSERT @tasks SELECT C.TaskID FROM dbo.TDCLCorrectiveTask C JOIN @inspections I ON I.ID=C.InspectionID WHERE C.CompanyID=@co;
DECLARE @schedules TABLE(ID bigint PRIMARY KEY);
INSERT @schedules SELECT S.ScheduleID FROM dbo.TDCLSchedule S JOIN @types T ON T.ID=S.TypeID WHERE S.CompanyID=@co;
DECLARE @newAssignments TABLE(ID bigint PRIMARY KEY);
INSERT @newAssignments SELECT EntityID FROM dbo.TDCLAudit WHERE CompanyID=@co AND ActionCode='SEED' AND EntityCode='EMPLOYEE_ASSIGNMENT' AND Detail=@run;
DECLARE @newUserProjects TABLE(ID bigint PRIMARY KEY);
INSERT @newUserProjects SELECT EntityID FROM dbo.TDCLAudit WHERE CompanyID=@co AND ActionCode='SEED' AND EntityCode='USER_PROJECT' AND Detail=@run;
DECLARE @seededSetting bit=CASE WHEN EXISTS(SELECT 1 FROM dbo.TDCLAudit WHERE CompanyID=@co AND ActionCode='SEED' AND EntityCode='SETTING' AND EntityID=@co AND Detail=@run) THEN 1 ELSE 0 END;
IF EXISTS(SELECT 1 FROM dbo.TDADEmployeeOrganizationAssignment A JOIN @newAssignments X ON X.ID=A.EmployeeOrganizationAssignmentID WHERE A.CompanyID=@co AND A.UpdateDate IS NOT NULL)
  THROW 58827,N'A fixture-created employee assignment was modified; review it manually',1;
DELETE N FROM dbo.TDCLNotification N JOIN @inspections I ON I.ID=N.InspectionID WHERE N.CompanyID=@co;
DELETE A FROM dbo.TDCLApproval A JOIN @inspections I ON I.ID=A.InspectionID WHERE A.CompanyID=@co;
DELETE C FROM dbo.TDCLCorrectiveTask C JOIN @tasks T ON T.ID=C.TaskID WHERE C.CompanyID=@co;
DELETE X FROM dbo.TDCLInspectionItem X JOIN @inspections I ON I.ID=X.InspectionID WHERE X.CompanyID=@co;
DELETE V FROM dbo.TDCLInspectionVersion V JOIN @inspections I ON I.ID=V.InspectionID WHERE V.CompanyID=@co;
DELETE I FROM dbo.TDCLInspection I JOIN @inspections X ON X.ID=I.InspectionID WHERE I.CompanyID=@co;
DELETE S FROM dbo.TDCLSchedule S JOIN @schedules X ON X.ID=S.ScheduleID WHERE S.CompanyID=@co;
DELETE X FROM dbo.TDCLWorkflowStep X JOIN dbo.TDCLWorkflow W ON W.CompanyID=X.CompanyID AND W.WorkflowID=X.WorkflowID JOIN @types T ON T.ID=W.TypeID WHERE X.CompanyID=@co;
DELETE W FROM dbo.TDCLWorkflow W JOIN @types T ON T.ID=W.TypeID WHERE W.CompanyID=@co;
DELETE X FROM dbo.TDCLTemplateItem X JOIN dbo.TDCLTemplate T ON T.CompanyID=X.CompanyID AND T.TemplateID=X.TemplateID JOIN @types Y ON Y.ID=T.TypeID WHERE X.CompanyID=@co;
DELETE T FROM dbo.TDCLTemplate T JOIN @types X ON X.ID=T.TypeID WHERE T.CompanyID=@co;
DELETE T FROM dbo.TDCLType T JOIN @types X ON X.ID=T.TypeID WHERE T.CompanyID=@co;
DELETE FROM dbo.TDCLGroup WHERE CompanyID=@co AND GroupID=@group AND GroupCode=@run+N'_IT';
DELETE A FROM dbo.TDCLAudit A WHERE A.CompanyID=@co AND
  ((A.ActionCode='SEED' AND A.Detail=@run) OR
   (A.EntityCode='INSPECTION' AND EXISTS(SELECT 1 FROM @inspections I WHERE I.ID=A.EntityID)) OR
   (A.EntityCode='CORRECTIVE_TASK' AND EXISTS(SELECT 1 FROM @tasks T WHERE T.ID=A.EntityID)) OR
   (A.EntityCode='SCHEDULE' AND EXISTS(SELECT 1 FROM @schedules S WHERE S.ID=A.EntityID)));
IF @seededSetting=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDCLGroup WHERE CompanyID=@co)
  DELETE FROM dbo.TDCLSetting WHERE CompanyID=@co AND ProjectID=@project AND TimeZoneId=N'Asia/Bangkok' AND NotifyEmail=0;
DELETE FROM dbo.TDADUserPermission WHERE ProjectID=@project AND Remark=@run;
DELETE P FROM dbo.TDADUserProject P JOIN @newUserProjects X ON X.ID=P.UserProjectID WHERE P.CompanyID=@co AND P.ProjectID=@project;
DELETE A FROM dbo.TDADEmployeeOrganizationAssignment A JOIN @newAssignments X ON X.ID=A.EmployeeOrganizationAssignmentID
WHERE A.CompanyID=@co AND A.CreateBy=@actor AND A.UpdateDate IS NULL;
DELETE FROM dbo.TDADCompanyFeature WHERE CompanyID=@co AND ProjectID=@project;
DELETE FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@project;
DELETE FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND ReasonText=@run;
COMMIT;
SELECT @run RetiredRunID,@co CompanyID;
