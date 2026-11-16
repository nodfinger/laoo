IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'55003' AND (ScreenType<>1 OR RouteName<>N'companySupplierContacts'))
    THROW 51000, 'Menu 55003 already exists with a different contract.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'55002' AND ScreenType=1)
    THROW 51001, 'Menu 55002 is required as the supplier menu template.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'55003')
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,ShowPermissionPoint,RunData,AllowListDisplaySettings,AllowDataAccessSettings,RequiresApproval,AllowPrint,AllowExport,AllowResponsibleOrgUnit,SendToNotificationSystem,AllowDivisionWorkView,AllowDepartmentWorkView)
    SELECT N'55003',MenuGroupCode,N'ข้อมูลผู้ขาย/ผู้ติดต่อ',1,N'companySupplierContacts',N'/company/supplier-contacts',FeatureCode,IconName,SortOrder+1,IsVisible,IsFavoriteAllowed,IsActive,ShowPermissionPoint,0,0,0,0,0,0,0,0,0,0 FROM dbo.TDADMainMenu WHERE MenuCode=N'55002';
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
SELECT pm.ProjectID,N'55003',pm.MenuGroupCode,pm.SortOrder+1,pm.IsActive
FROM dbo.TDADProjectMenu pm JOIN dbo.TDADProject p ON p.ProjectID=pm.ProjectID AND p.ProjectCode=N'LAOO_OCR'
WHERE pm.MenuCode=N'55002' AND NOT EXISTS (SELECT 1 FROM dbo.TDADProjectMenu x WHERE x.ProjectID=pm.ProjectID AND x.MenuCode=N'55003');

IF COL_LENGTH(N'dbo.TDAPVendor',N'DataSource') IS NULL
    ALTER TABLE dbo.TDAPVendor ADD DataSource tinyint NOT NULL CONSTRAINT DF_TDAPVendor_DataSource DEFAULT (0) WITH VALUES;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDAPVendor') AND name=N'CK_TDAPVendor_DataSource')
    EXEC(N'ALTER TABLE dbo.TDAPVendor WITH CHECK ADD CONSTRAINT CK_TDAPVendor_DataSource CHECK (DataSource IN (0, 1))');

IF OBJECT_ID(N'dbo.TDSTSupplierBusinessCardDraft',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSTSupplierBusinessCardDraft (
  DraftID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_SupplierBusinessCardDraft PRIMARY KEY,
  CompanyID bigint NOT NULL, SubmittedBy bigint NOT NULL,
  Status varchar(12) NOT NULL CONSTRAINT DF_SupplierBusinessCardDraft_Status DEFAULT ('DRAFT'),
  Payload nvarchar(max) NOT NULL, CreatedAt datetime2 NOT NULL CONSTRAINT DF_SupplierBusinessCardDraft_CreatedAt DEFAULT SYSUTCDATETIME(),
  SentAt datetime2 NULL, ReviewedAt datetime2 NULL, ReviewedBy bigint NULL, VendorID bigint NULL, VendorContactID bigint NULL,
  RowVersion rowversion NOT NULL,
  CONSTRAINT CK_SupplierBusinessCardDraft_Status CHECK (Status IN ('DRAFT','PENDING','APPROVED','DELETED')),
  CONSTRAINT CK_SupplierBusinessCardDraft_Payload CHECK (ISJSON(Payload)=1)
 );
 CREATE INDEX IX_SupplierBusinessCardDraft_CompanyStatus ON dbo.TDSTSupplierBusinessCardDraft(CompanyID,Status,DraftID DESC) INCLUDE(SubmittedBy);
END;
IF OBJECT_ID(N'dbo.TDSTSupplierBusinessCardDraftImage',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSTSupplierBusinessCardDraftImage (
  DraftImageID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_SupplierBusinessCardDraftImage PRIMARY KEY,
  DraftID bigint NOT NULL,CompanyID bigint NOT NULL,OriginalName nvarchar(255) NOT NULL,ImageData varbinary(max) NOT NULL,
  CreatedAt datetime2 NOT NULL CONSTRAINT DF_SupplierBusinessCardDraftImage_CreatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_SupplierBusinessCardDraftImage_Draft FOREIGN KEY(DraftID) REFERENCES dbo.TDSTSupplierBusinessCardDraft(DraftID)
 );
 CREATE INDEX IX_SupplierBusinessCardDraftImage_Draft ON dbo.TDSTSupplierBusinessCardDraftImage(CompanyID,DraftID);
END;
IF OBJECT_ID(N'dbo.TDAPVendorContact',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDAPVendorContact (
  VendorContactID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPVendorContact PRIMARY KEY,
  CompanyID bigint NOT NULL,VendorID bigint NOT NULL,FullName nvarchar(200) NOT NULL,PositionName nvarchar(200) NULL,
  Phone nvarchar(50) NULL,Email nvarchar(320) NULL,Address nvarchar(1000) NULL,Website nvarchar(320) NULL,LineID nvarchar(100) NULL,
  CreatedAt datetime2 NOT NULL CONSTRAINT DF_TDAPVendorContact_CreatedAt DEFAULT SYSUTCDATETIME(),CreatedBy bigint NOT NULL,
  RowVersion rowversion NOT NULL,CONSTRAINT FK_TDAPVendorContact_Vendor FOREIGN KEY(VendorID) REFERENCES dbo.TDAPVendor(VendorID)
 );
 CREATE INDEX IX_TDAPVendorContact_CompanyVendor ON dbo.TDAPVendorContact(CompanyID,VendorID);
END;
