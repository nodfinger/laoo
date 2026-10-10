SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @CoreProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @CoreProjectID IS NULL THROW 59100, N'LAOO core project is required', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode IN (N'09010',N'09019',N'09020'))
   AND EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09010' AND (ScreenType<>4 OR RouteName<>N'companyPurchaseTaxInvoices'))
    THROW 59101, N'09010 menu conflicts with purchase tax invoice contract', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09019' AND (ScreenType<>3 OR RouteName<>N'companySalesTaxReport'))
    THROW 59102, N'09019 menu conflicts with sales tax report contract', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09020' AND (ScreenType<>3 OR RouteName<>N'companyPurchaseTaxReport'))
    THROW 59103, N'09020 menu conflicts with purchase tax report contract', 1;

DECLARE @Menus table(Code char(5), Name nvarchar(100), ScreenType int, RouteName nvarchar(100), RoutePath nvarchar(200), SortOrder int);
INSERT @Menus VALUES
(N'09010',N'ใบกำกับภาษีซื้อ',4,N'companyPurchaseTaxInvoices',N'/company/purchase-tax-invoices',10),
(N'09019',N'รายงานภาษีขาย',3,N'companySalesTaxReport',N'/company/sales-tax-report',19),
(N'09020',N'รายงานภาษีซื้อ',3,N'companyPurchaseTaxReport',N'/company/purchase-tax-report',20);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
SELECT Code,N'09',Name,ScreenType,RouteName,RoutePath,N'SALES',N'receipt_long_outlined',SortOrder,1,1,1
FROM @Menus M WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu X WHERE X.MenuCode=M.Code);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @CoreProjectID,M.Code,N'09',M.SortOrder,1,SYSUTCDATETIME()
FROM @Menus M WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu X WHERE X.ProjectID=@CoreProjectID AND X.MenuCode=M.Code);
DECLARE @Actions table(Code char(5), ActionCode nvarchar(20), Name nvarchar(50));
INSERT @Actions VALUES
(N'09010',N'VIEW',N'แสดง'),(N'09010',N'CREATE',N'เพิ่ม'),(N'09010',N'EDIT',N'แก้ไข'),
(N'09019',N'VIEW',N'แสดง'),(N'09020',N'VIEW',N'แสดง');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @CoreProjectID,A.Code,M.Name,M.RouteName,A.ActionCode,A.Name,A.ActionCode,1,SYSUTCDATETIME()
FROM @Actions A JOIN @Menus M ON M.Code=A.Code
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@CoreProjectID AND P.ScreenCode=A.Code AND P.ActionCode=A.ActionCode);

IF COL_LENGTH(N'dbo.TDADBranch',N'TaxBranchCode') IS NULL
    ALTER TABLE dbo.TDADBranch ADD TaxBranchCode nvarchar(5) NULL;
IF COL_LENGTH(N'dbo.TDARTaxInvoice',N'BranchID') IS NULL
    ALTER TABLE dbo.TDARTaxInvoice ADD BranchID bigint NULL;
IF COL_LENGTH(N'dbo.TDARTaxInvoice',N'CustomerTaxBranchCode') IS NULL
    ALTER TABLE dbo.TDARTaxInvoice ADD CustomerTaxBranchCode nvarchar(5) NULL;

IF OBJECT_ID(N'dbo.TDAPTaxInvoice',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPTaxInvoice(
        PurchaseTaxInvoiceID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPTaxInvoice PRIMARY KEY,
        CompanyID bigint NOT NULL,
        BranchID bigint NULL,
        VendorID bigint NOT NULL,
        VendorNameSnapshot nvarchar(200) NOT NULL,
        VendorTaxIDSnapshot nvarchar(20) NULL,
        VendorTaxBranchCode nvarchar(5) NULL,
        InternalCode nvarchar(30) NOT NULL,
        SupplierInvoiceCode nvarchar(100) NOT NULL,
        InvoiceDate date NOT NULL,
        ReceivedDate date NOT NULL,
        TaxYear int NOT NULL,
        TaxMonth tinyint NOT NULL,
        TaxBase decimal(18,2) NOT NULL,
        TaxRate decimal(6,2) NOT NULL,
        TaxAmount decimal(18,2) NOT NULL,
        ClaimStatus nvarchar(20) NOT NULL,
        ClaimReason nvarchar(500) NULL,
        StatusCode nvarchar(20) NOT NULL,
        RunID nvarchar(80) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDAPTaxInvoice_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NOT NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        CONSTRAINT CK_TDAPTaxInvoice_Period CHECK(TaxYear BETWEEN 2000 AND 2200 AND TaxMonth BETWEEN 1 AND 12),
        CONSTRAINT CK_TDAPTaxInvoice_Amount CHECK(TaxBase>=0 AND TaxAmount>=0 AND TaxRate>=0),
        CONSTRAINT CK_TDAPTaxInvoice_Claim CHECK(ClaimStatus IN (N'ELIGIBLE',N'INELIGIBLE',N'REVIEW')),
        CONSTRAINT CK_TDAPTaxInvoice_Status CHECK(StatusCode IN (N'DRAFT',N'CONFIRMED',N'VOID')),
        CONSTRAINT UQ_TDAPTaxInvoice_Internal UNIQUE(CompanyID,InternalCode)
    );
    CREATE INDEX IX_TDAPTaxInvoice_Report ON dbo.TDAPTaxInvoice(CompanyID,TaxYear,TaxMonth,BranchID,StatusCode);
END;
IF OBJECT_ID(N'dbo.TDAPTaxInvoiceDetail',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPTaxInvoiceDetail(
        PurchaseTaxInvoiceDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPTaxInvoiceDetail PRIMARY KEY,
        PurchaseTaxInvoiceID bigint NOT NULL CONSTRAINT FK_TDAPTaxInvoiceDetail_Header REFERENCES dbo.TDAPTaxInvoice(PurchaseTaxInvoiceID),
        ItemNo int NOT NULL,
        Description nvarchar(500) NOT NULL,
        Quantity decimal(18,4) NOT NULL,
        UnitPrice decimal(18,4) NOT NULL,
        TaxBase decimal(18,2) NOT NULL,
        CONSTRAINT CK_TDAPTaxInvoiceDetail_Quantity CHECK(Quantity>0),
        CONSTRAINT CK_TDAPTaxInvoiceDetail_Price CHECK(UnitPrice>=0),
        CONSTRAINT UQ_TDAPTaxInvoiceDetail_Line UNIQUE(PurchaseTaxInvoiceID,ItemNo)
    );
END;

IF OBJECT_ID(N'dbo.TDADTaxReportSnapshot',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADTaxReportSnapshot(
        SnapshotID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADTaxReportSnapshot PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ReportType nvarchar(10) NOT NULL,
        BranchID bigint NULL,
        TaxYear int NOT NULL,
        TaxMonth tinyint NOT NULL,
        Revision int NOT NULL,
        ClosedAt datetime2(3) NOT NULL CONSTRAINT DF_TDADTaxReportSnapshot_ClosedAt DEFAULT SYSUTCDATETIME(),
        ClosedBy bigint NOT NULL,
        TotalBase decimal(18,2) NOT NULL,
        TotalTax decimal(18,2) NOT NULL,
        CONSTRAINT CK_TDADTaxReportSnapshot_Type CHECK(ReportType IN (N'SALE',N'PURCHASE')),
        CONSTRAINT UQ_TDADTaxReportSnapshot_Revision UNIQUE(CompanyID,ReportType,BranchID,TaxYear,TaxMonth,Revision)
    );
    CREATE TABLE dbo.TDADTaxReportSnapshotLine(
        SnapshotLineID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADTaxReportSnapshotLine PRIMARY KEY,
        SnapshotID bigint NOT NULL CONSTRAINT FK_TDADTaxReportSnapshotLine_Parent REFERENCES dbo.TDADTaxReportSnapshot(SnapshotID),
        SourceID bigint NOT NULL,
        SourceCode nvarchar(100) NOT NULL,
        TaxBase decimal(18,2) NOT NULL,
        TaxAmount decimal(18,2) NOT NULL,
        CONSTRAINT UQ_TDADTaxReportSnapshotLine_Source UNIQUE(SnapshotID,SourceID)
    );
END;
COMMIT TRANSACTION;
