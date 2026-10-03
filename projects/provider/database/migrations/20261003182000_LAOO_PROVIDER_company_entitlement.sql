SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PROVIDER' AND IsActive=1);
 IF @Project IS NULL THROW 57120,N'LAOO_PROVIDER project is missing.',1;
 INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,CreateDate,CreatedBy)
 SELECT @Project,c.PartnerID,c.CompanyID,1,0,SYSUTCDATETIME(),NULL
 FROM dbo.TDSTCompanySetUp c
 WHERE c.IsActive=1 AND c.PartnerID IS NOT NULL AND c.CompanyID IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject x WHERE x.ProjectID=@Project AND x.PartnerID=c.PartnerID AND x.CompanyID=c.CompanyID);
 UPDATE cp SET IsEnabled=1,ExpireDate=NULL,UpdateDate=SYSUTCDATETIME()
 FROM dbo.TDADCompanyProject cp JOIN dbo.TDSTCompanySetUp c ON c.CompanyID=cp.CompanyID AND c.PartnerID=cp.PartnerID AND c.IsActive=1
 WHERE cp.ProjectID=@Project;
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
 SELECT u.CompanyID,u.UserID,@Project,0,1,SYSUTCDATETIME(),u.UserID
 FROM dbo.TDADUser u JOIN dbo.TDSTCompanySetUp c ON c.CompanyID=u.CompanyID AND c.IsActive=1
 WHERE u.IsActive=1 AND u.IsCompanyAdmin=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject x WHERE x.CompanyID=u.CompanyID AND x.UserID=u.UserID AND x.ProjectID=@Project);
 UPDATE up SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=up.UserID FROM dbo.TDADUserProject up JOIN dbo.TDADUser u ON u.UserID=up.UserID AND u.CompanyID=up.CompanyID AND u.IsActive=1 AND u.IsCompanyAdmin=1 WHERE up.ProjectID=@Project;
 INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
 SELECT u.UserID,@Project,p.PermissionID,1,1,N'LAOO_PROVIDER company admin baseline',u.UserID
 FROM dbo.TDADUser u CROSS JOIN dbo.TDADPermission p
 WHERE u.IsActive=1 AND u.IsCompanyAdmin=1 AND p.ProjectID=@Project AND p.IsActive=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission x WHERE x.UserID=u.UserID AND x.ProjectID=@Project AND x.PermissionID=p.PermissionID);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
