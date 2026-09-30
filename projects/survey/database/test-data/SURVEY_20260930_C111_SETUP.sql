SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Company bigint=(SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @User bigint=(SELECT UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
DECLARE @Employee bigint=(SELECT TOP(1) EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@Company AND UserID=@User AND IsActive=1 ORDER BY UserEmployeeID);
DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SURVEY' AND IsActive=1);
DECLARE @Partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@Company AND IsActive=1);
DECLARE @AdminRole bigint=(SELECT TOP(1) RoleGroupID FROM dbo.TDADRoleGroup WHERE CompanyID=@Company AND RoleCode=N'ca' AND IsActive=1);

IF @Company IS NULL OR @User IS NULL OR @Employee IS NULL OR @Project IS NULL OR @Partner IS NULL OR @AdminRole IS NULL
    THROW 56410,N'c111 Survey fixture prerequisites are missing.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company)
    INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,CreateDate,CreatedBy)
    VALUES(@Project,@Partner,@Company,1,0,SYSUTCDATETIME(),@User);
ELSE
    UPDATE dbo.TDADCompanyProject SET IsEnabled=1,ExpireDate=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@User
    WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project)
    INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
    VALUES(@Company,@User,@Project,0,1,SYSUTCDATETIME(),@User);
ELSE
    UPDATE dbo.TDADUserProject SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@User
    WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project;

MERGE dbo.TDADRoleGroupPermission AS target
USING(
    SELECT @AdminRole RoleGroupID,ProjectID,ScreenCode MenuCode,ActionCode
    FROM dbo.TDADPermission WHERE ProjectID=@Project AND IsActive=1
) source
ON target.RoleGroupID=source.RoleGroupID AND target.ProjectID=source.ProjectID
 AND target.MenuCode=source.MenuCode AND target.ActionCode=source.ActionCode
WHEN MATCHED THEN UPDATE SET IsAllowed=1,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=N'SURVEY-20260930-C111'
WHEN NOT MATCHED THEN INSERT(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedUtc,CreatedBy)
VALUES(source.RoleGroupID,source.ProjectID,source.MenuCode,source.ActionCode,1,SYSUTCDATETIME(),N'SURVEY-20260930-C111');

IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemSurvey WHERE CompanyID=@Company)
    INSERT dbo.TDSTCompanySetupSystemSurvey(CompanyID,ProjectID,IsEnabled,DefaultDurationDays,RequireApproval,DefaultAnonymous,ResultsAfterClose,DefaultApproverEmployeeID,CreateBy)
    VALUES(@Company,@Project,1,14,1,1,1,@Employee,@User);
ELSE
    UPDATE dbo.TDSTCompanySetupSystemSurvey
    SET IsEnabled=1,DefaultDurationDays=14,RequireApproval=1,DefaultAnonymous=1,
        ResultsAfterClose=1,DefaultApproverEmployeeID=@Employee,UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
    WHERE CompanyID=@Company;

COMMIT TRANSACTION;
