SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDARQuotation', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARQuotation
    (
        QuotationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARQuotation PRIMARY KEY,
        CompanyID bigint NOT NULL,
        QuoteCode nvarchar(30) NOT NULL,
        QuoteDate date NOT NULL CONSTRAINT DF_TDARQuotation_QuoteDate DEFAULT CONVERT(date, SYSUTCDATETIME()),
        CustomerID bigint NOT NULL,
        CusCode nvarchar(50) NOT NULL,
        CusName nvarchar(200) NOT NULL,
        SalespersonUserID bigint NULL,
        SalespersonEmployeeID bigint NULL,
        SalespersonName nvarchar(200) NULL,
        ContactName nvarchar(200) NULL,
        ValidDays int NULL,
        SalesType nvarchar(100) NULL,
        PaymentType nvarchar(50) NULL,
        CreditDays int NULL,
        VATPercent decimal(9,2) NOT NULL CONSTRAINT DF_TDARQuotation_VATPercent DEFAULT (7),
        TotalAmount decimal(18,2) NULL,
        DiscountPercent decimal(9,2) NULL,
        DiscountAmount decimal(18,2) NULL,
        AmountAfterDiscount decimal(18,2) NULL,
        TaxPercent decimal(9,2) NULL,
        TaxAmount decimal(18,2) NULL,
        NetAmount decimal(18,2) NULL,
        StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDARQuotation_StatusCode DEFAULT N'DRAFT',
        Remark nvarchar(1000) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDARQuotation_IsActive DEFAULT (1),
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDARQuotation_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(7) NULL,
        UpdatedBy bigint NULL,
        CONSTRAINT UQ_TDARQuotation_Company_QuoteCode UNIQUE (CompanyID, QuoteCode)
    );
END;

IF OBJECT_ID(N'dbo.TDARQuotationDetail', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARQuotationDetail
    (
        QuotationDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARQuotationDetail PRIMARY KEY,
        QuotationID bigint NOT NULL,
        [LineNo] int NOT NULL,
        ItemID bigint NOT NULL,
        ItemCode nvarchar(50) NOT NULL,
        ItemName nvarchar(200) NOT NULL,
        UnitCode nvarchar(50) NULL,
        Quantity decimal(18,4) NOT NULL,
        UnitPrice decimal(18,4) NOT NULL,
        DiscountType nvarchar(1) NOT NULL CONSTRAINT DF_TDARQuotationDetail_DiscountType DEFAULT (N'N'),
        BeforeDiscount decimal(18,4) NOT NULL CONSTRAINT DF_TDARQuotationDetail_BeforeDiscount DEFAULT (0),
        DiscountPercent decimal(9,4) NOT NULL CONSTRAINT DF_TDARQuotationDetail_Discount DEFAULT (0),
        DiscountAmount decimal(18,4) NOT NULL CONSTRAINT DF_TDARQuotationDetail_DiscountAmount DEFAULT (0),
        Amount decimal(18,4) NOT NULL,
        CONSTRAINT FK_TDARQuotationDetail_Quotation FOREIGN KEY (QuotationID) REFERENCES dbo.TDARQuotation(QuotationID) ON DELETE CASCADE,
        CONSTRAINT FK_TDARQuotationDetail_Item FOREIGN KEY (ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT UQ_TDARQuotationDetail_Line UNIQUE (QuotationID, [LineNo]),
        CONSTRAINT CK_TDARQuotationDetail_DiscountType CHECK (DiscountType IN (N'N',N'P',N'A')),
        CONSTRAINT CK_TDARQuotationDetail_DiscountValue CHECK
        (
            DiscountPercent >= 0 AND DiscountPercent <= 100
            AND DiscountAmount >= 0
            AND DiscountAmount <= BeforeDiscount
            AND Amount = BeforeDiscount - DiscountAmount
        )
    );
END;

COMMIT TRANSACTION;

SELECT name FROM sys.tables WHERE name IN (N'TDARQuotation', N'TDARQuotationDetail');
