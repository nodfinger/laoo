SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PROVIDER' AND IsActive=1);
 IF @ProjectID IS NULL THROW 57130,N'LAOO_PROVIDER project is missing.',1;
 UPDATE dbo.TDADMenuGroup SET AudienceType=N'A',UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=N'51';
 INSERT dbo.TDADLaooUserProject(LaooUserID,ProjectID,CanAccess,CanLoginAsUser,IsActive,CreateDate,CreateBy)
 SELECT u.LaooUserID,@ProjectID,1,0,1,SYSUTCDATETIME(),u.LaooUserID FROM dbo.TDADLaooUser u
 WHERE u.IsSupportUser=1 AND u.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDADLaooUserProject x WHERE x.LaooUserID=u.LaooUserID AND x.ProjectID=@ProjectID);
 UPDATE up SET CanAccess=1,IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=up.LaooUserID FROM dbo.TDADLaooUserProject up JOIN dbo.TDADLaooUser u ON u.LaooUserID=up.LaooUserID AND u.IsSupportUser=1 AND u.IsActive=1 WHERE up.ProjectID=@ProjectID;
 INSERT dbo.TDADLaooUserPermission(LaooUserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedDate,CreatedBy)
 SELECT u.LaooUserID,@ProjectID,p.PermissionID,1,1,N'LAOO_PROVIDER support baseline',SYSUTCDATETIME(),u.LaooUserID
 FROM dbo.TDADLaooUser u CROSS JOIN dbo.TDADPermission p
 WHERE u.IsSupportUser=1 AND u.IsActive=1 AND p.ProjectID=@ProjectID AND p.IsActive=1
 AND p.ScreenCode IN(N'51002',N'51003',N'51005',N'51007',N'51008')
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADLaooUserPermission x WHERE x.LaooUserID=u.LaooUserID AND x.ProjectID=@ProjectID AND x.PermissionID=p.PermissionID);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
