SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @ProjectID IS NULL THROW 59120, N'LAOO core project is required', 1;

DECLARE @Menus table(Code char(5), Name nvarchar(100), ScreenType int, RouteName nvarchar(100), RoutePath nvarchar(200), SortOrder int);
INSERT @Menus VALUES
(N'09008',N'ตั้งค่าระบบภาษี',2,N'companyVatSettings',N'/company/vat-settings',8),
(N'09009',N'ใบส่งของซื้อ',4,N'companyPurchaseDeliveries',N'/company/purchase-deliveries',9),
(N'09011',N'ลูกหนี้และประวัติขาย',3,N'companyReceivables',N'/company/receivables',11),
(N'09012',N'รับชำระหนี้',4,N'companyReceipts',N'/company/receipts',12),
(N'09013',N'ติดตามลูกหนี้',3,N'companyReceivableFollowUp',N'/company/receivable-follow-up',13),
(N'09014',N'เจ้าหนี้และประวัติซื้อ',3,N'companyPayables',N'/company/payables',14),
(N'09015',N'จ่ายชำระหนี้',4,N'companyPayments',N'/company/payments',15),
(N'09016',N'ติดตามเจ้าหนี้',3,N'companyPayableFollowUp',N'/company/payable-follow-up',16),
(N'09021',N'ใบเพิ่ม–ลดหนี้ขาย',4,N'companySalesTaxAdjustments',N'/company/sales-tax-adjustments',21),
(N'09022',N'ใบเพิ่ม–ลดหนี้ซื้อ',4,N'companyPurchaseTaxAdjustments',N'/company/purchase-tax-adjustments',22);

IF EXISTS (
    SELECT 1 FROM @Menus M JOIN dbo.TDADMainMenu X ON X.MenuCode=M.Code
    WHERE X.ScreenType<>M.ScreenType OR X.RouteName<>M.RouteName
) THROW 59121, N'Finance menu contract conflicts with existing metadata', 1;

INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
SELECT M.Code,N'09',M.Name,M.ScreenType,M.RouteName,M.RoutePath,N'SALES',N'receipt_long_outlined',M.SortOrder,1,1,1
FROM @Menus M WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu X WHERE X.MenuCode=M.Code);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ProjectID,M.Code,N'09',M.SortOrder,1,SYSUTCDATETIME()
FROM @Menus M WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu X WHERE X.ProjectID=@ProjectID AND X.MenuCode=M.Code);

DECLARE @Actions table(Code char(5), ActionCode nvarchar(20), Name nvarchar(50));
INSERT @Actions
SELECT M.Code,A.ActionCode,A.Name
FROM @Menus M
CROSS APPLY (VALUES
 (N'VIEW',N'แสดง'),(N'CREATE',N'เพิ่ม'),(N'EDIT',N'แก้ไข'),(N'DELETE',N'ลบ'),
 (N'CONFIRM',N'ยืนยัน'),(N'REVERSE',N'กลับรายการ'),(N'CLOSE',N'ปิดเดือน'),(N'EXPORT',N'ส่งออก')
) A(ActionCode,Name)
WHERE A.ActionCode=N'VIEW'
   OR (M.ScreenType=2 AND A.ActionCode IN (N'EDIT',N'CLOSE'))
   OR (M.ScreenType=4 AND A.ActionCode IN (N'CREATE',N'EDIT',N'DELETE',N'CONFIRM',N'REVERSE',N'EXPORT'));
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,A.Code,M.Name,M.RouteName,A.ActionCode,A.Name,A.ActionCode,1,SYSUTCDATETIME()
FROM @Actions A JOIN @Menus M ON M.Code=A.Code
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ProjectID AND P.ScreenCode=A.Code AND P.ActionCode=A.ActionCode);

IF COL_LENGTH(N'dbo.TDSTCompanySetUp',N'IsVatRegistered') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD IsVatRegistered bit NULL;

IF OBJECT_ID(N'dbo.TDAPPurchaseDelivery',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPPurchaseDelivery(
        PurchaseDeliveryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPurchaseDelivery PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, VendorID bigint NOT NULL,
        DeliveryCode nvarchar(30) NOT NULL, SupplierDocumentCode nvarchar(100) NULL,
        DeliveryDate date NOT NULL, PaymentType nvarchar(10) NOT NULL, CreditDays int NOT NULL,
        DueDate date NULL, TotalAmount decimal(18,2) NOT NULL, StatusCode nvarchar(20) NOT NULL,
        Remark nvarchar(1000) NULL, RunID nvarchar(80) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDAPPurchaseDelivery_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL, UpdateDate datetime2(3) NULL, UpdatedBy bigint NULL,
        ConfirmDate datetime2(3) NULL, ConfirmedBy bigint NULL,
        CONSTRAINT UQ_TDAPPurchaseDelivery_Code UNIQUE(CompanyID,DeliveryCode),
        CONSTRAINT CK_TDAPPurchaseDelivery_Payment CHECK(PaymentType IN (N'CASH',N'CREDIT')),
        CONSTRAINT CK_TDAPPurchaseDelivery_Status CHECK(StatusCode IN (N'DRAFT',N'CONFIRMED',N'VOID')),
        CONSTRAINT CK_TDAPPurchaseDelivery_Amount CHECK(TotalAmount>=0 AND CreditDays>=0)
    );
    CREATE INDEX IX_TDAPPurchaseDelivery_List ON dbo.TDAPPurchaseDelivery(CompanyID,DeliveryDate,StatusCode);
    CREATE TABLE dbo.TDAPPurchaseDeliveryDetail(
        PurchaseDeliveryDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPurchaseDeliveryDetail PRIMARY KEY,
        PurchaseDeliveryID bigint NOT NULL CONSTRAINT FK_TDAPPurchaseDeliveryDetail_Header REFERENCES dbo.TDAPPurchaseDelivery(PurchaseDeliveryID),
        ItemNo int NOT NULL, ItemID bigint NULL, Description nvarchar(500) NOT NULL,
        Quantity decimal(18,4) NOT NULL, UnitPrice decimal(18,4) NOT NULL, Amount decimal(18,2) NOT NULL,
        CONSTRAINT UQ_TDAPPurchaseDeliveryDetail_Line UNIQUE(PurchaseDeliveryID,ItemNo),
        CONSTRAINT CK_TDAPPurchaseDeliveryDetail_Amount CHECK(Quantity>0 AND UnitPrice>=0 AND Amount>=0)
    );
END;

IF OBJECT_ID(N'dbo.TDARReceivable',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARReceivable(
        ReceivableID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARReceivable PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, CustomerID bigint NOT NULL,
        SourceType nvarchar(30) NOT NULL, SourceID bigint NOT NULL, SourceCode nvarchar(50) NOT NULL,
        DocumentDate date NOT NULL, DueDate date NOT NULL, OriginalAmount decimal(18,2) NOT NULL,
        StatusCode nvarchar(20) NOT NULL, RunID nvarchar(80) NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDARReceivable_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL,
        CONSTRAINT UQ_TDARReceivable_Source UNIQUE(CompanyID,SourceType,SourceID),
        CONSTRAINT CK_TDARReceivable_Source CHECK(SourceType IN (N'DELIVERY_NOTE',N'TAX_INVOICE')),
        CONSTRAINT CK_TDARReceivable_Amount CHECK(OriginalAmount>=0),
        CONSTRAINT CK_TDARReceivable_Status CHECK(StatusCode IN (N'OPEN',N'SETTLED',N'VOID'))
    );
    CREATE INDEX IX_TDARReceivable_Due ON dbo.TDARReceivable(CompanyID,DueDate,StatusCode);
    CREATE TABLE dbo.TDARReceipt(
        ReceiptID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARReceipt PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, CustomerID bigint NOT NULL,
        ReceiptCode nvarchar(30) NOT NULL, ReceiptDate date NOT NULL, Amount decimal(18,2) NOT NULL,
        PaymentMethod nvarchar(20) NOT NULL, PaymentReference nvarchar(100) NULL,
        StatusCode nvarchar(20) NOT NULL, ReversalReason nvarchar(500) NULL, RunID nvarchar(80) NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDARReceipt_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL, PostedAt datetime2(3) NULL, ReversedAt datetime2(3) NULL, ReversedBy bigint NULL,
        CONSTRAINT UQ_TDARReceipt_Code UNIQUE(CompanyID,ReceiptCode),
        CONSTRAINT CK_TDARReceipt_Amount CHECK(Amount>0),
        CONSTRAINT CK_TDARReceipt_Method CHECK(PaymentMethod IN (N'CASH',N'TRANSFER')),
        CONSTRAINT CK_TDARReceipt_Status CHECK(StatusCode IN (N'DRAFT',N'POSTED',N'REVERSED'))
    );
    CREATE TABLE dbo.TDARReceiptAllocation(
        ReceiptAllocationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARReceiptAllocation PRIMARY KEY,
        ReceiptID bigint NOT NULL CONSTRAINT FK_TDARReceiptAllocation_Receipt REFERENCES dbo.TDARReceipt(ReceiptID),
        ReceivableID bigint NOT NULL CONSTRAINT FK_TDARReceiptAllocation_Debt REFERENCES dbo.TDARReceivable(ReceivableID),
        Amount decimal(18,2) NOT NULL CONSTRAINT CK_TDARReceiptAllocation_Amount CHECK(Amount>0),
        CONSTRAINT UQ_TDARReceiptAllocation_Target UNIQUE(ReceiptID,ReceivableID)
    );
END;

IF OBJECT_ID(N'dbo.TDAPPayable',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPPayable(
        PayableID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPayable PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, VendorID bigint NOT NULL,
        SourceType nvarchar(30) NOT NULL, SourceID bigint NOT NULL, SourceCode nvarchar(100) NOT NULL,
        DocumentDate date NOT NULL, DueDate date NOT NULL, OriginalAmount decimal(18,2) NOT NULL,
        StatusCode nvarchar(20) NOT NULL, RunID nvarchar(80) NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDAPPayable_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL,
        CONSTRAINT UQ_TDAPPayable_Source UNIQUE(CompanyID,SourceType,SourceID),
        CONSTRAINT CK_TDAPPayable_Source CHECK(SourceType IN (N'PURCHASE_DELIVERY',N'PURCHASE_TAX_INVOICE')),
        CONSTRAINT CK_TDAPPayable_Amount CHECK(OriginalAmount>=0),
        CONSTRAINT CK_TDAPPayable_Status CHECK(StatusCode IN (N'OPEN',N'SETTLED',N'VOID'))
    );
    CREATE INDEX IX_TDAPPayable_Due ON dbo.TDAPPayable(CompanyID,DueDate,StatusCode);
    CREATE TABLE dbo.TDAPPayment(
        PaymentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPayment PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, VendorID bigint NOT NULL,
        PaymentCode nvarchar(30) NOT NULL, PaymentDate date NOT NULL, Amount decimal(18,2) NOT NULL,
        PaymentMethod nvarchar(20) NOT NULL, PaymentReference nvarchar(100) NULL,
        StatusCode nvarchar(20) NOT NULL, ReversalReason nvarchar(500) NULL, RunID nvarchar(80) NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDAPPayment_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL, PostedAt datetime2(3) NULL, ReversedAt datetime2(3) NULL, ReversedBy bigint NULL,
        CONSTRAINT UQ_TDAPPayment_Code UNIQUE(CompanyID,PaymentCode),
        CONSTRAINT CK_TDAPPayment_Amount CHECK(Amount>0),
        CONSTRAINT CK_TDAPPayment_Method CHECK(PaymentMethod IN (N'CASH',N'TRANSFER')),
        CONSTRAINT CK_TDAPPayment_Status CHECK(StatusCode IN (N'DRAFT',N'POSTED',N'REVERSED'))
    );
    CREATE TABLE dbo.TDAPPaymentAllocation(
        PaymentAllocationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPaymentAllocation PRIMARY KEY,
        PaymentID bigint NOT NULL CONSTRAINT FK_TDAPPaymentAllocation_Payment REFERENCES dbo.TDAPPayment(PaymentID),
        PayableID bigint NOT NULL CONSTRAINT FK_TDAPPaymentAllocation_Debt REFERENCES dbo.TDAPPayable(PayableID),
        Amount decimal(18,2) NOT NULL CONSTRAINT CK_TDAPPaymentAllocation_Amount CHECK(Amount>0),
        CONSTRAINT UQ_TDAPPaymentAllocation_Target UNIQUE(PaymentID,PayableID)
    );
END;

IF OBJECT_ID(N'dbo.TDARTaxAdjustment',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARTaxAdjustment(
        AdjustmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARTaxAdjustment PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, TaxInvoiceID bigint NOT NULL,
        AdjustmentCode nvarchar(30) NOT NULL, AdjustmentDate date NOT NULL,
        AdjustmentType nvarchar(10) NOT NULL, TaxBase decimal(18,2) NOT NULL,
        TaxAmount decimal(18,2) NOT NULL, Reason nvarchar(500) NOT NULL,
        StatusCode nvarchar(20) NOT NULL, RunID nvarchar(80) NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDARTaxAdjustment_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL, IssuedAt datetime2(3) NULL, IssuedBy bigint NULL,
        CONSTRAINT UQ_TDARTaxAdjustment_Code UNIQUE(CompanyID,AdjustmentCode),
        CONSTRAINT CK_TDARTaxAdjustment_Type CHECK(AdjustmentType IN (N'INCREASE',N'DECREASE')),
        CONSTRAINT CK_TDARTaxAdjustment_Amount CHECK(TaxBase>=0 AND TaxAmount>=0),
        CONSTRAINT CK_TDARTaxAdjustment_Status CHECK(StatusCode IN (N'DRAFT',N'ISSUED',N'VOID'))
    );
END;
IF OBJECT_ID(N'dbo.TDAPTaxAdjustment',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPTaxAdjustment(
        AdjustmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPTaxAdjustment PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, PurchaseTaxInvoiceID bigint NOT NULL,
        AdjustmentCode nvarchar(30) NOT NULL, SupplierAdjustmentCode nvarchar(100) NULL,
        AdjustmentDate date NOT NULL, AdjustmentType nvarchar(10) NOT NULL,
        TaxBase decimal(18,2) NOT NULL, TaxAmount decimal(18,2) NOT NULL,
        Reason nvarchar(500) NOT NULL, StatusCode nvarchar(20) NOT NULL, RunID nvarchar(80) NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_TDAPTaxAdjustment_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL, ConfirmedAt datetime2(3) NULL, ConfirmedBy bigint NULL,
        CONSTRAINT UQ_TDAPTaxAdjustment_Code UNIQUE(CompanyID,AdjustmentCode),
        CONSTRAINT CK_TDAPTaxAdjustment_Type CHECK(AdjustmentType IN (N'INCREASE',N'DECREASE')),
        CONSTRAINT CK_TDAPTaxAdjustment_Amount CHECK(TaxBase>=0 AND TaxAmount>=0),
        CONSTRAINT CK_TDAPTaxAdjustment_Status CHECK(StatusCode IN (N'DRAFT',N'CONFIRMED',N'VOID'))
    );
END;
IF OBJECT_ID(N'dbo.TDADFinanceAudit',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADFinanceAudit(
        AuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADFinanceAudit PRIMARY KEY,
        CompanyID bigint NOT NULL, BranchID bigint NULL, EntityType nvarchar(40) NOT NULL,
        EntityID bigint NOT NULL, ActionCode nvarchar(30) NOT NULL, Reason nvarchar(500) NULL,
        ActorUserID bigint NOT NULL, OccurredAt datetime2(3) NOT NULL
            CONSTRAINT DF_TDADFinanceAudit_OccurredAt DEFAULT SYSUTCDATETIME(),
        RunID nvarchar(80) NULL
    );
    CREATE INDEX IX_TDADFinanceAudit_Entity ON dbo.TDADFinanceAudit(CompanyID,EntityType,EntityID,OccurredAt);
END;
COMMIT TRANSACTION;
