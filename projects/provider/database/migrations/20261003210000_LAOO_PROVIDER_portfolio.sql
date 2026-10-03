SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PROVIDER' AND IsActive=1);
 IF @ProjectID IS NULL THROW 57140,N'LAOO_PROVIDER project is missing.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'51009' AND MenuGroupCode<>N'51') THROW 57141,N'Provider portfolio MenuCode conflict.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE (RouteName=N'providerPortfolio' OR RoutePath=N'/company/provider-portfolio') AND MenuCode<>N'51009') THROW 57142,N'Provider portfolio route conflict.',1;

 IF COL_LENGTH(N'dbo.TDSTCompanySetUp',N'MemberCoverImagePath') IS NULL ALTER TABLE dbo.TDSTCompanySetUp ADD MemberCoverImagePath nvarchar(1000) NULL;
 IF COL_LENGTH(N'dbo.TDSTCompanySetUp',N'MemberCoverMimeType') IS NULL ALTER TABLE dbo.TDSTCompanySetUp ADD MemberCoverMimeType nvarchar(100) NULL;
 IF COL_LENGTH(N'dbo.TDSTCompanySetUp',N'MemberCoverSizeBytes') IS NULL ALTER TABLE dbo.TDSTCompanySetUp ADD MemberCoverSizeBytes bigint NULL;

 IF OBJECT_ID(N'dbo.TDPRPortfolio',N'U') IS NULL CREATE TABLE dbo.TDPRPortfolio(
  PortfolioID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPRPortfolio PRIMARY KEY,CompanyID bigint NOT NULL,WorkTitle nvarchar(200) NOT NULL,ServiceDate date NOT NULL,
  CoverImagePath nvarchar(1000) NOT NULL,CoverMimeType nvarchar(100) NOT NULL,CoverSizeBytes bigint NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDPRPortfolio_Active DEFAULT(1),CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRPortfolio_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT CK_TDPRPortfolio_CoverSize CHECK(CoverSizeBytes BETWEEN 1 AND 1048576));
 IF OBJECT_ID(N'dbo.TDPRPortfolioImage',N'U') IS NULL CREATE TABLE dbo.TDPRPortfolioImage(
  PortfolioImageID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPRPortfolioImage PRIMARY KEY,PortfolioID bigint NOT NULL,CompanyID bigint NOT NULL,
  ImagePath nvarchar(1000) NOT NULL,MimeType nvarchar(100) NOT NULL,SizeBytes bigint NOT NULL,SortOrder int NOT NULL CONSTRAINT DF_TDPRPortfolioImage_Sort DEFAULT(0),
  CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRPortfolioImage_Create DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDPRPortfolioImage_Portfolio FOREIGN KEY(PortfolioID) REFERENCES dbo.TDPRPortfolio(PortfolioID) ON DELETE CASCADE,
  CONSTRAINT CK_TDPRPortfolioImage_Size CHECK(SizeBytes BETWEEN 1 AND 1048576));
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPRPortfolio') AND name=N'IX_TDPRPortfolio_Company') CREATE INDEX IX_TDPRPortfolio_Company ON dbo.TDPRPortfolio(CompanyID,IsActive,ServiceDate DESC,PortfolioID DESC);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPRPortfolioImage') AND name=N'IX_TDPRPortfolioImage_Portfolio') CREATE INDEX IX_TDPRPortfolioImage_Portfolio ON dbo.TDPRPortfolioImage(PortfolioID,SortOrder,PortfolioImageID);

 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'51009' AND ScreenType<>1) THROW 57143,N'Provider portfolio ScreenType conflict.',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'51009')
  UPDATE dbo.TDADMainMenu SET MenuGroupCode=N'51',MenuName=N'ผลงานที่ผ่านมา',ScreenType=1,RouteName=N'providerPortfolio',RoutePath=N'/company/provider-portfolio',FeatureCode=N'PROVIDER_PORTFOLIO',IconName=N'photo_library_outlined',SortOrder=90,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'51009';
 ELSE INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
  VALUES(N'51009',N'51',N'ผลงานที่ผ่านมา',1,N'providerPortfolio',N'/company/provider-portfolio',N'PROVIDER_PORTFOLIO',N'photo_library_outlined',90,1,1,1,SYSUTCDATETIME(),0);
 IF EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode=N'51009')
  UPDATE dbo.TDADProjectMenu SET MenuGroupCode=N'51',SortOrder=90,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode=N'51009';
 ELSE INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,N'51009',N'51',90,1,SYSUTCDATETIME());
 DECLARE @Actions TABLE(ActionCode nvarchar(50) PRIMARY KEY); INSERT @Actions VALUES(N'VIEW'),(N'CREATE'),(N'EDIT'),(N'DELETE');
 UPDATE p SET ScreenNameTH=N'ผลงานที่ผ่านมา',ScreenNameEN=N'PROVIDER_PORTFOLIO',ActionNameTH=a.ActionCode,ActionNameEN=a.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME()
 FROM dbo.TDADPermission p JOIN @Actions a ON a.ActionCode=p.ActionCode WHERE p.ProjectID=@ProjectID AND p.ScreenCode=N'51009';
 INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
 SELECT @ProjectID,N'51009',N'ผลงานที่ผ่านมา',N'PROVIDER_PORTFOLIO',a.ActionCode,a.ActionCode,a.ActionCode,1,SYSUTCDATETIME() FROM @Actions a
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission p WHERE p.ProjectID=@ProjectID AND p.ScreenCode=N'51009' AND p.ActionCode=a.ActionCode);
 INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
 SELECT u.UserID,@ProjectID,p.PermissionID,1,1,N'LAOO_PROVIDER portfolio company admin baseline',u.UserID
 FROM dbo.TDADUser u JOIN dbo.TDADPermission p ON p.ProjectID=@ProjectID AND p.ScreenCode=N'51009' AND p.IsActive=1
 WHERE u.IsActive=1 AND u.IsCompanyAdmin=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission x WHERE x.UserID=u.UserID AND x.ProjectID=@ProjectID AND x.PermissionID=p.PermissionID);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
