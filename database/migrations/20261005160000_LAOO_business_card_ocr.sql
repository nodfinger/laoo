-- Additive OCR schema. Execute only through the approved migration runner.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @ProjectID IS NULL THROW 55501,'LAOO project required.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'55001' AND (ScreenType<>2 OR ISNULL(RouteName,N'')<>N'companyBusinessCardOcrSettings'))
 OR EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'55002' AND (ScreenType<>1 OR ISNULL(RouteName,N'')<>N'companyContacts'))
 THROW 55502,'OCR menu collision.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode NOT IN(N'55001',N'55002') AND RoutePath IN(N'/company/business-card-ocr-settings',N'/company/contacts'))
 THROW 55503,'OCR route collision.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'55' AND MenuGroupName<>N'ระบบ OCR นามบัตร')
 THROW 55504,'OCR menu group collision.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'55')
 INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
 VALUES(N'C',N'55',N'ระบบ OCR นามบัตร',N'document_scanner',550,0,1,SYSUTCDATETIME(),0,0);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=N'55')
 INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
 VALUES(@ProjectID,N'55',550,1,SYSUTCDATETIME());
IF OBJECT_ID(N'dbo.TDSTBusinessCardOcrSetting',N'U') IS NULL
CREATE TABLE dbo.TDSTBusinessCardOcrSetting(
 -- TDSTCompanySetUp is a legacy heap and CompanyID is not a candidate key.
 -- Company scope is validated by the authenticated API before every action.
 CompanyID bigint NOT NULL PRIMARY KEY,
 IsEnabled bit NOT NULL DEFAULT(1),
 MaxImageSizeMB int NOT NULL DEFAULT(10) CHECK(MaxImageSizeMB BETWEEN 1 AND 10),
 TimeoutSeconds int NOT NULL DEFAULT(30) CHECK(TimeoutSeconds BETWEEN 5 AND 120),
 UpdateDate datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,RowVersion rowversion NOT NULL);
IF OBJECT_ID(N'dbo.TDADContact',N'U') IS NULL
CREATE TABLE dbo.TDADContact(
 ContactID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,
 PersonID bigint NOT NULL,OwnsPerson bit NOT NULL DEFAULT(0),
 CustomerID bigint NULL,
 CompanyName nvarchar(250) NULL,PositionName nvarchar(200) NULL,Address nvarchar(1000) NULL,
 Website nvarchar(500) NULL,LineID nvarchar(100) NULL,IsActive bit NOT NULL DEFAULT(1),IsDeleted bit NOT NULL DEFAULT(0),
 CreateDate datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),CreateBy bigint NULL,
 UpdateDate datetime2(3) NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDADContact_CompanyPerson UNIQUE(CompanyID,PersonID),
 CONSTRAINT UQ_TDADContact_CompanyContact UNIQUE(CompanyID,ContactID),
 CONSTRAINT FK_TDADContact_Person FOREIGN KEY(CompanyID,PersonID)
  REFERENCES dbo.TDADPerson(CompanyID,PersonID));
IF OBJECT_ID(N'dbo.TDADContactFile',N'U') IS NULL
CREATE TABLE dbo.TDADContactFile(
 ContactFileID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,
 ContactID bigint NOT NULL,
 OriginalName nvarchar(255) NOT NULL,StoredName nvarchar(100) NOT NULL,ContentType nvarchar(100) NOT NULL,
 FileSize bigint NOT NULL,Sha256 char(64) NOT NULL,CreateDate datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),CreateBy bigint NOT NULL,
 CONSTRAINT FK_TDADContactFile_Contact FOREIGN KEY(CompanyID,ContactID)
  REFERENCES dbo.TDADContact(CompanyID,ContactID));
IF OBJECT_ID(N'dbo.TDADBusinessCardOcrAudit',N'U') IS NULL
CREATE TABLE dbo.TDADBusinessCardOcrAudit(
 AuditID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,
 UserID bigint NOT NULL,TargetType varchar(20) NOT NULL,ResultCode varchar(40) NOT NULL,
 DurationMilliseconds int NOT NULL,WordCount int NOT NULL DEFAULT(0),CreateDate datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()));
DECLARE @Menus TABLE(Code char(5),Name nvarchar(150),ScreenType int,RouteName nvarchar(150),Path nvarchar(300),Icon nvarchar(100),GroupCode char(2));
INSERT @Menus VALUES
 (N'55001',N'ตั้งค่า OCR นามบัตร',2,N'companyBusinessCardOcrSettings',N'/company/business-card-ocr-settings',N'document_scanner',N'55'),
 (N'55002',N'ทะเบียนผู้ติดต่อ',1,N'companyContacts',N'/company/contacts',N'contacts',N'55');
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,ShowPermissionPoint,CreateDate)
SELECT Code,GroupCode,Name,ScreenType,RouteName,Path,Icon,90,1,1,1,0,SYSUTCDATETIME() FROM @Menus M
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=M.Code);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ProjectID,Code,GroupCode,90,1,SYSUTCDATETIME() FROM @Menus M
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode=M.Code);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,M.Code,M.Name,M.RouteName,A.ActionCode,A.ActionCode,A.ActionCode,1,SYSUTCDATETIME()
FROM @Menus M CROSS JOIN(VALUES(N'VIEW'),(N'CREATE'),(N'EDIT'),(N'DELETE')) A(ActionCode)
WHERE (M.ScreenType=1 OR A.ActionCode IN(N'VIEW',N'EDIT'))
AND NOT EXISTS(SELECT 1 FROM dbo.TDADPermission WHERE ProjectID=@ProjectID AND ScreenCode=M.Code AND ActionCode=A.ActionCode);
COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
