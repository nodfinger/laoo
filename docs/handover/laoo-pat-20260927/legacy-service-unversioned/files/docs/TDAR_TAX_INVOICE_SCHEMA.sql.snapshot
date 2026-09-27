SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDARQuotation',N'U') IS NULL THROW 50201,N'ไม่พบ dbo.TDARQuotation',1;
IF OBJECT_ID(N'dbo.TDARPreOrder',N'U') IS NULL THROW 50202,N'ไม่พบ dbo.TDARPreOrder',1;
IF OBJECT_ID(N'dbo.TDARTemporaryReceipt',N'U') IS NULL THROW 50203,N'ไม่พบ dbo.TDARTemporaryReceipt',1;
IF OBJECT_ID(N'dbo.TDARCustomer',N'U') IS NULL THROW 50204,N'ไม่พบ dbo.TDARCustomer',1;
IF OBJECT_ID(N'dbo.TDIVItem',N'U') IS NULL THROW 50205,N'ไม่พบ dbo.TDIVItem',1;

IF OBJECT_ID(N'dbo.TDARTaxInvoice',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARTaxInvoice
    (
        TaxInvoiceID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARTaxInvoice PRIMARY KEY,
        CompanyID bigint NOT NULL,
        TaxInvoiceCode nvarchar(30) NOT NULL,
        TaxInvoiceDate date NOT NULL CONSTRAINT DF_TDARTaxInvoice_Date DEFAULT CONVERT(date,SYSUTCDATETIME()),
        ReferenceType nvarchar(30) NOT NULL CONSTRAINT DF_TDARTaxInvoice_ReferenceType DEFAULT(N'NONE'),
        QuotationID bigint NULL,
        PreOrderID bigint NULL,
        TemporaryReceiptID bigint NULL,
        CustomerID bigint NOT NULL,
        CusCode nvarchar(50) NOT NULL,
        CusName nvarchar(200) NOT NULL,
        CusAddress nvarchar(1000) NULL,
        TaxID nvarchar(30) NULL,
        ContactName nvarchar(200) NULL,
        ContactPhone nvarchar(100) NULL,
        ContactEmail nvarchar(200) NULL,
        PaymentType nvarchar(50) NULL,
        CreditDays int NOT NULL CONSTRAINT DF_TDARTaxInvoice_CreditDays DEFAULT(0),
        DueDate date NULL,
        Subtotal decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoice_Subtotal DEFAULT(0),
        DiscountPercent decimal(9,4) NOT NULL CONSTRAINT DF_TDARTaxInvoice_DiscountPercent DEFAULT(0),
        DiscountAmount decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoice_DiscountAmount DEFAULT(0),
        AmountAfterDiscount decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoice_AfterDiscount DEFAULT(0),
        TaxPercent decimal(9,4) NOT NULL CONSTRAINT DF_TDARTaxInvoice_TaxPercent DEFAULT(7),
        TaxAmount decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoice_TaxAmount DEFAULT(0),
        NetAmount decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoice_NetAmount DEFAULT(0),
        StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDARTaxInvoice_Status DEFAULT(N'DRAFT'),
        Remark nvarchar(1000) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDARTaxInvoice_Active DEFAULT(1),
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDARTaxInvoice_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(7) NULL,
        UpdatedBy bigint NULL,
        CONSTRAINT UQ_TDARTaxInvoice_Company_Code UNIQUE(CompanyID,TaxInvoiceCode),
        CONSTRAINT FK_TDARTaxInvoice_Quotation FOREIGN KEY(QuotationID) REFERENCES dbo.TDARQuotation(QuotationID),
        CONSTRAINT FK_TDARTaxInvoice_PreOrder FOREIGN KEY(PreOrderID) REFERENCES dbo.TDARPreOrder(PreOrderID),
        CONSTRAINT FK_TDARTaxInvoice_TemporaryReceipt FOREIGN KEY(TemporaryReceiptID) REFERENCES dbo.TDARTemporaryReceipt(TemporaryReceiptID),
        CONSTRAINT CK_TDARTaxInvoice_Status CHECK(StatusCode IN(N'DRAFT',N'ISSUED',N'VOID')),
        CONSTRAINT CK_TDARTaxInvoice_Reference CHECK
        (
            (ReferenceType=N'NONE' AND QuotationID IS NULL AND PreOrderID IS NULL AND TemporaryReceiptID IS NULL) OR
            (ReferenceType=N'QUOTATION' AND QuotationID IS NOT NULL AND PreOrderID IS NULL AND TemporaryReceiptID IS NULL) OR
            (ReferenceType=N'PREORDER' AND QuotationID IS NULL AND PreOrderID IS NOT NULL AND TemporaryReceiptID IS NULL) OR
            (ReferenceType=N'TEMP_RECEIPT' AND QuotationID IS NULL AND PreOrderID IS NULL AND TemporaryReceiptID IS NOT NULL)
        ),
        CONSTRAINT CK_TDARTaxInvoice_Amounts CHECK
        (
            CreditDays>=0 AND Subtotal>=0 AND DiscountPercent BETWEEN 0 AND 100 AND
            DiscountAmount>=0 AND DiscountAmount<=Subtotal AND AmountAfterDiscount>=0 AND
            TaxPercent BETWEEN 0 AND 100 AND TaxAmount>=0 AND NetAmount>=0
        )
    );
    CREATE INDEX IX_TDARTaxInvoice_CompanyDate ON dbo.TDARTaxInvoice(CompanyID,TaxInvoiceDate,TaxInvoiceID);
END;

IF OBJECT_ID(N'dbo.TDARTaxInvoiceDetail',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARTaxInvoiceDetail
    (
        TaxInvoiceDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARTaxInvoiceDetail PRIMARY KEY,
        TaxInvoiceID bigint NOT NULL,
        [LineNo] int NOT NULL,
        QuotationDetailID bigint NULL,
        PreOrderDetailID bigint NULL,
        ItemID bigint NOT NULL,
        ItemCode nvarchar(50) NOT NULL,
        ItemName nvarchar(200) NOT NULL,
        UnitCode nvarchar(50) NULL,
        Quantity decimal(18,4) NOT NULL,
        UnitPrice decimal(18,4) NOT NULL,
        DiscountType nvarchar(1) NOT NULL CONSTRAINT DF_TDARTaxInvoiceDetail_DiscountType DEFAULT(N'N'),
        BeforeDiscount decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoiceDetail_BeforeDiscount DEFAULT(0),
        DiscountPercent decimal(9,4) NOT NULL CONSTRAINT DF_TDARTaxInvoiceDetail_DiscountPercent DEFAULT(0),
        DiscountAmount decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoiceDetail_DiscountAmount DEFAULT(0),
        Amount decimal(18,4) NOT NULL CONSTRAINT DF_TDARTaxInvoiceDetail_Amount DEFAULT(0),
        Remark nvarchar(500) NULL,
        CONSTRAINT FK_TDARTaxInvoiceDetail_Header FOREIGN KEY(TaxInvoiceID) REFERENCES dbo.TDARTaxInvoice(TaxInvoiceID) ON DELETE CASCADE,
        CONSTRAINT FK_TDARTaxInvoiceDetail_QuotationDetail FOREIGN KEY(QuotationDetailID) REFERENCES dbo.TDARQuotationDetail(QuotationDetailID),
        CONSTRAINT FK_TDARTaxInvoiceDetail_PreOrderDetail FOREIGN KEY(PreOrderDetailID) REFERENCES dbo.TDARPreOrderDetail(PreOrderDetailID),
        CONSTRAINT FK_TDARTaxInvoiceDetail_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT UQ_TDARTaxInvoiceDetail_Line UNIQUE(TaxInvoiceID,[LineNo]),
        CONSTRAINT CK_TDARTaxInvoiceDetail_DiscountType CHECK(DiscountType IN(N'N',N'P',N'A')),
        CONSTRAINT CK_TDARTaxInvoiceDetail_Values CHECK
        (
            Quantity>0 AND UnitPrice>=0 AND BeforeDiscount>=0 AND
            DiscountPercent BETWEEN 0 AND 100 AND DiscountAmount>=0 AND
            DiscountAmount<=BeforeDiscount AND Amount>=0
        )
    );
    CREATE INDEX IX_TDARTaxInvoiceDetail_Item ON dbo.TDARTaxInvoiceDetail(ItemID,TaxInvoiceID);
END;

COMMIT TRANSACTION;

SELECT name FROM sys.tables WHERE name IN(N'TDARTaxInvoice',N'TDARTaxInvoiceDetail');
