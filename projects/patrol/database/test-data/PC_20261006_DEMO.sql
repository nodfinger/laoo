SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @run nvarchar(40)=N'PC_20261006_DEMO';
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND IsActive=1);
DECLARE @branch bigint=(SELECT TOP(1) BranchID FROM dbo.TDADBranch WHERE CompanyID=@co ORDER BY CASE WHEN BranchCode=N'HO' THEN 0 ELSE 1 END,BranchID);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@co AND Username=N'c' AND IsActive=1);
DECLARE @employee bigint=(SELECT TOP(1) UE.EmployeeID FROM dbo.TDADUser U JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=U.CompanyID AND UE.UserID=U.UserID AND UE.IsActive=1 WHERE U.CompanyID=@co AND U.Username=N'c111' AND U.IsActive=1 ORDER BY UE.UserEmployeeID);
DECLARE @partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PATROL');
DECLARE @timeProject bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME');
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD');
IF @co IS NULL OR @branch IS NULL OR @actor IS NULL OR @employee IS NULL THROW 57650,N'DEMO/c/employee/branch prerequisites missing',1;
IF @project IS NULL OR @package IS NULL OR @timeProject IS NULL THROW 57651,N'Patrol or Time project prerequisites missing',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@timeProject AND IsEnabled=1) THROW 57652,N'LAOO_TIME must be enabled for DEMO',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1)
BEGIN
 INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,ReasonText,CreateBy)
 VALUES(@partner,@co,@project,@package,N'TRIAL',CONVERT(date,SYSUTCDATETIME()),DATEADD(day,60,CONVERT(date,SYSUTCDATETIME())),@run,@actor);
 INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,1,1,CONVERT(date,SYSUTCDATETIME()),DATEADD(day,60,CONVERT(date,SYSUTCDATETIME())),@actor
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@project);
 INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,F.FeatureCode,1,1,CONVERT(date,SYSUTCDATETIME()),DATEADD(day,60,CONVERT(date,SYSUTCDATETIME())),@actor
 FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=@package AND F.IsEnabled=1;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@co AND UserID=@actor AND ProjectID=@project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
 VALUES(@co,@actor,@project,0,1,SYSUTCDATETIME(),@actor);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @actor,@project,P.PermissionID,1,1,@run,@actor FROM dbo.TDADPermission P
WHERE P.ProjectID=@project AND P.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U WHERE U.UserID=@actor AND U.ProjectID=@project AND U.PermissionID=P.PermissionID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDPCCredential WHERE CompanyID=@co AND CredentialType=N'CARD' AND CredentialRefHash=HASHBYTES('SHA2_256',CONVERT(varchar(100),N'PC-CARD-0001')))
 INSERT dbo.TDPCCredential(CompanyID,EmployeeID,CredentialType,CredentialRefHash,CredentialHint) VALUES(@co,@employee,N'CARD',HASHBYTES('SHA2_256',CONVERT(varchar(100),N'PC-CARD-0001')),N'0001');
IF NOT EXISTS(SELECT 1 FROM dbo.TDPCSetting WHERE CompanyID=@co)
 INSERT dbo.TDPCSetting(CompanyID,ProjectID,DefaultGraceBeforeMinutes,DefaultGraceAfterMinutes,OfflineMaxHours,GpsRadiusMeters,EscalateAfterMinutes)
 VALUES(@co,@project,5,10,24,100,30);
INSERT dbo.TDPCCheckpoint(CompanyID,BranchID,CheckpointCode,CheckpointName,TimeMode,RequireGps,RequirePhoto,RequireChecklist,AllowedMethods)
SELECT @co,@branch,V.Code,V.Name,V.Mode,V.Gps,V.Photo,V.Checklist,N'CARD,QR,NFC,FINGERPRINT,FACE,SIMULATOR'
FROM (VALUES
(@run+N'_GATE',N'Main security gate',N'TIME_WINDOW',CONVERT(bit,0),CONVERT(bit,1),CONVERT(bit,1)),
(@run+N'_ELEC',N'Electrical control room',N'ANYTIME_IN_RUN',CONVERT(bit,0),CONVERT(bit,0),CONVERT(bit,1)),
(@run+N'_WC',N'Public restroom',N'ANYTIME_IN_RUN',CONVERT(bit,0),CONVERT(bit,1),CONVERT(bit,1))) V(Code,Name,Mode,Gps,Photo,Checklist)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDPCCheckpoint C WHERE C.CompanyID=@co AND C.CheckpointCode=V.Code);
INSERT dbo.TDPCChecklistTemplate(CompanyID,TemplateCode,TemplateName,WorkType)
SELECT @co,V.Code,V.Name,V.WorkType FROM (VALUES
(@run+N'_SEC',N'Security checkpoint checklist',N'SECURITY'),
(@run+N'_HK',N'Housekeeping checkpoint checklist',N'HOUSEKEEPING')) V(Code,Name,WorkType)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDPCChecklistTemplate T WHERE T.CompanyID=@co AND T.TemplateCode=V.Code);
INSERT dbo.TDPCChecklistItem(CompanyID,TemplateID,SequenceNo,ItemText)
SELECT @co,T.TemplateID,V.Seq,V.ItemText FROM dbo.TDPCChecklistTemplate T
CROSS APPLY(VALUES(1,N'Area is safe and accessible'),(2,N'No visible damage or hazard')) V(Seq,ItemText)
WHERE T.CompanyID=@co AND T.TemplateCode=@run+N'_SEC'
AND NOT EXISTS(SELECT 1 FROM dbo.TDPCChecklistItem I WHERE I.CompanyID=@co AND I.TemplateID=T.TemplateID AND I.SequenceNo=V.Seq);
INSERT dbo.TDPCChecklistItem(CompanyID,TemplateID,SequenceNo,ItemText)
SELECT @co,T.TemplateID,V.Seq,V.ItemText FROM dbo.TDPCChecklistTemplate T
CROSS APPLY(VALUES(1,N'Area is clean'),(2,N'Supplies are available')) V(Seq,ItemText)
WHERE T.CompanyID=@co AND T.TemplateCode=@run+N'_HK'
AND NOT EXISTS(SELECT 1 FROM dbo.TDPCChecklistItem I WHERE I.CompanyID=@co AND I.TemplateID=T.TemplateID AND I.SequenceNo=V.Seq);
INSERT dbo.TDPCRoute(CompanyID,BranchID,RouteCode,RouteName,WorkType,SequenceMode)
SELECT @co,@branch,V.Code,V.Name,V.WorkType,V.SequenceMode FROM (VALUES
(@run+N'_SEC',N'Security morning route',N'SECURITY',N'STRICT'),
(@run+N'_HK',N'Housekeeping flexible route',N'HOUSEKEEPING',N'FLEXIBLE')) V(Code,Name,WorkType,SequenceMode)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDPCRoute R WHERE R.CompanyID=@co AND R.RouteCode=V.Code);
DECLARE @secRoute bigint=(SELECT RouteID FROM dbo.TDPCRoute WHERE CompanyID=@co AND RouteCode=@run+N'_SEC');
DECLARE @hkRoute bigint=(SELECT RouteID FROM dbo.TDPCRoute WHERE CompanyID=@co AND RouteCode=@run+N'_HK');
DECLARE @secTemplate bigint=(SELECT TemplateID FROM dbo.TDPCChecklistTemplate WHERE CompanyID=@co AND TemplateCode=@run+N'_SEC');
DECLARE @hkTemplate bigint=(SELECT TemplateID FROM dbo.TDPCChecklistTemplate WHERE CompanyID=@co AND TemplateCode=@run+N'_HK');
INSERT dbo.TDPCRouteCheckpoint(CompanyID,RouteID,CheckpointID,SequenceNo,TimeMode,WindowStart,WindowEnd,GraceBeforeMinutes,GraceAfterMinutes,ChecklistTemplateID)
SELECT @co,@secRoute,C.CheckpointID,V.Seq,V.Mode,V.FromTime,V.ToTime,5,10,@secTemplate
FROM (VALUES(@run+N'_GATE',1,N'TIME_WINDOW',CONVERT(time,'08:00'),CONVERT(time,'08:15')),(@run+N'_ELEC',2,N'ANYTIME_IN_RUN',CONVERT(time,NULL),CONVERT(time,NULL))) V(Code,Seq,Mode,FromTime,ToTime)
JOIN dbo.TDPCCheckpoint C ON C.CompanyID=@co AND C.CheckpointCode=V.Code
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDPCRouteCheckpoint X WHERE X.CompanyID=@co AND X.RouteID=@secRoute AND X.SequenceNo=V.Seq);
INSERT dbo.TDPCRouteCheckpoint(CompanyID,RouteID,CheckpointID,SequenceNo,TimeMode,WindowStart,WindowEnd,GraceBeforeMinutes,GraceAfterMinutes,ChecklistTemplateID)
SELECT @co,@hkRoute,C.CheckpointID,1,N'ANYTIME_IN_RUN',NULL,NULL,0,10,@hkTemplate
FROM dbo.TDPCCheckpoint C WHERE C.CompanyID=@co AND C.CheckpointCode=@run+N'_WC'
AND NOT EXISTS(SELECT 1 FROM dbo.TDPCRouteCheckpoint X WHERE X.CompanyID=@co AND X.RouteID=@hkRoute);
DECLARE @start datetime2(3)=DATEADD(hour,-1,SYSUTCDATETIME()),@finish datetime2(3)=DATEADD(hour,7,SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM dbo.TDPCSchedule WHERE CompanyID=@co AND ScheduleCode=@run+N'_S1')
 INSERT dbo.TDPCSchedule(CompanyID,RouteID,ScheduleCode,ScheduleName,StartsAt,EndsAt,AssignedEmployeeID,StatusCode,CreatedBy)
 VALUES(@co,@secRoute,@run+N'_S1',N'Sample security shift',@start,@finish,@employee,N'PLANNED',@actor);
UPDATE dbo.TDPCSchedule SET AssignedEmployeeID=@employee WHERE CompanyID=@co AND ScheduleCode=@run+N'_S1';
COMMIT;
