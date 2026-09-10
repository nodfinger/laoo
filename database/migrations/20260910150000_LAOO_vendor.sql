-- Approved Core Vendor 08007. Run only through the transactional migration runner.
SET XACT_ABORT ON;
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @project IS NULL THROW 52700,'Active Core project required.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode='08007')
 THROW 52701,'Menu 08007 already exists; review ownership before migration.',1;
CREATE TABLE dbo.TDAPVendor (
 VendorID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPVendor PRIMARY KEY,
 CompanyID bigint NOT NULL,
 CompanySetupID bigint NOT NULL,
 VendorCode nvarchar(50) NOT NULL,
 VendorName nvarchar(200) NOT NULL,
 EntityTypeCode varchar(20) NOT NULL,
 TaxID nvarchar(50) NULL,
 Address nvarchar(1000) NULL,
 Telephone nvarchar(50) NULL,
 Email nvarchar(320) NULL,
 ContactName nvarchar(200) NULL,
 ContactTelephone nvarchar(50) NULL,
 ContactEmail nvarchar(320) NULL,
 CreditDays int NOT NULL CONSTRAINT DF_TDAPVendor_CreditDays DEFAULT(0),
 Remark nvarchar(1000) NULL,
 IsActive bit NOT NULL CONSTRAINT DF_TDAPVendor_IsActive DEFAULT(1),
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDAPVendor_CreateDate DEFAULT SYSUTCDATETIME(),
 CreatedBy bigint NOT NULL,
 UpdateDate datetime2(3) NULL,
 UpdatedBy bigint NULL,
 RowVersion rowversion NOT NULL,
 CONSTRAINT FK_TDAPVendor_Company FOREIGN KEY(CompanySetupID) REFERENCES dbo.TDSTCompanySetUp(PKValue),
 CONSTRAINT UQ_TDAPVendor_Company_Code UNIQUE(CompanyID,VendorCode),
 CONSTRAINT UQ_TDAPVendor_Company_ID UNIQUE(CompanyID,VendorID),
 CONSTRAINT CK_TDAPVendor_Type CHECK(EntityTypeCode IN('PERSON','ORGANIZATION')),
 CONSTRAINT CK_TDAPVendor_Credit CHECK(CreditDays BETWEEN 0 AND 3650),
 CONSTRAINT CK_TDAPVendor_Code CHECK(LEN(LTRIM(RTRIM(VendorCode)))>0),
 CONSTRAINT CK_TDAPVendor_Name CHECK(LEN(LTRIM(RTRIM(VendorName)))>0)
);
CREATE INDEX IX_TDAPVendor_Company_Name ON dbo.TDAPVendor(CompanyID,VendorName);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
VALUES('08007','08',N'ผู้ขาย',1,N'companyVendors',N'/company/vendors',N'storefront_outlined',7,1,1,1);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@project,'08007','08',7,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,IsActive)
SELECT @project,N'08007',N'ผู้ขาย',N'Vendors',ActionCode,ActionNameTH,1
FROM (VALUES('VIEW',N'แสดง'),('CREATE',N'เพิ่ม'),('EDIT',N'แก้ไข'),('DELETE',N'ลบ')) A(ActionCode,ActionNameTH);
-- No automatic grants to non-admin users and no technical metadata insertion.
