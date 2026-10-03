SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Company bigint=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
 DECLARE @User bigint=(SELECT TOP 1 UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
 DECLARE @Actor bigint=COALESCE((SELECT TOP 1 UserID FROM dbo.TDADUser WHERE Username=N'c' AND CompanyID=@Company AND IsActive=1),@User);
 DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PROVIDER' AND IsActive=1);
 IF @Company IS NULL OR @User IS NULL OR @Project IS NULL THROW 57160,N'Provider c111 access prerequisites are missing.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project)
  INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
  VALUES(@Company,@User,@Project,0,1,SYSUTCDATETIME(),@Actor);
 ELSE UPDATE dbo.TDADUserProject SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@Actor
  WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project;
 INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
 SELECT @User,@Project,p.PermissionID,1,1,N'LAOO_PROVIDER 51009 approved by owner',@Actor
 FROM dbo.TDADPermission p
 WHERE p.ProjectID=@Project AND p.ScreenCode=N'51009' AND p.ActionCode IN(N'VIEW',N'CREATE',N'EDIT',N'DELETE') AND p.IsActive=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission up WHERE up.UserID=@User AND up.ProjectID=@Project AND up.PermissionID=p.PermissionID);
 UPDATE up SET IsAllowed=1,IsActive=1,Remark=N'LAOO_PROVIDER 51009 approved by owner',ModifiedBy=@Actor,ModifiedDate=SYSUTCDATETIME()
 FROM dbo.TDADUserPermission up
 JOIN dbo.TDADPermission p ON p.PermissionID=up.PermissionID AND p.ProjectID=up.ProjectID
 WHERE up.UserID=@User AND up.ProjectID=@Project AND p.ScreenCode=N'51009' AND p.ActionCode IN(N'VIEW',N'CREATE',N'EDIT',N'DELETE') AND p.IsActive=1;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
