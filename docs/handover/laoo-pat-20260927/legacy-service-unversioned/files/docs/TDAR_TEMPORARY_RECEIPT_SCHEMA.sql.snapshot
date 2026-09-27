/*
    ใบเสร็จรับเงินชั่วคราว

    เอกสารอ้างอิงเลือกได้เพียงหนึ่งแบบ:
      - QuotationID มีค่า และ PreOrderID เป็น NULL
      - PreOrderID มีค่า และ QuotationID เป็น NULL
      - ไม่อ้างเอกสาร: ทั้งสองค่าเป็น NULL

    การเชื่อม Flow เอกสารบันทึกเพิ่มใน dbo.TDARDocumentLink โดย API
    ภายใน Transaction เดียวกับหัวเอกสารและรายการรับเงิน
*/

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDARQuotation', N'U') IS NULL
    THROW 50001, N'ไม่พบตาราง dbo.TDARQuotation', 1;
IF OBJECT_ID(N'dbo.TDARPreOrder', N'U') IS NULL
    THROW 50002, N'ไม่พบตาราง dbo.TDARPreOrder', 1;
IF OBJECT_ID(N'dbo.TDARDocumentLink', N'U') IS NULL
    THROW 50003, N'ไม่พบตาราง dbo.TDARDocumentLink', 1;

IF OBJECT_ID(N'dbo.TDARTemporaryReceipt', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARTemporaryReceipt
    (
        TemporaryReceiptID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDARTemporaryReceipt PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ReceiptCode nvarchar(30) NOT NULL,
        ReceiptDate date NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_ReceiptDate
            DEFAULT CONVERT(date, SYSUTCDATETIME()),
        QuotationID bigint NULL,
        PreOrderID bigint NULL,
        CustomerID bigint NOT NULL,
        CusCode nvarchar(50) NOT NULL,
        CusName nvarchar(200) NOT NULL,
        CusAddress nvarchar(1000) NULL,
        TaxID nvarchar(30) NULL,
        ContactName nvarchar(200) NULL,
        ReceivedFrom nvarchar(200) NOT NULL,
        ReferenceAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_ReferenceAmount DEFAULT (0),
        PreviouslyReceivedAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_PreviouslyReceived DEFAULT (0),
        ReceivedAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_ReceivedAmount DEFAULT (0),
        BalanceAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_BalanceAmount DEFAULT (0),
        StatusCode nvarchar(30) NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_StatusCode DEFAULT (N'DRAFT'),
        Remark nvarchar(1000) NULL,
        IsActive bit NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_IsActive DEFAULT (1),
        CreateDate datetime2(7) NOT NULL
            CONSTRAINT DF_TDARTemporaryReceipt_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(7) NULL,
        UpdatedBy bigint NULL,

        CONSTRAINT FK_TDARTemporaryReceipt_Quotation
            FOREIGN KEY (QuotationID) REFERENCES dbo.TDARQuotation(QuotationID),
        CONSTRAINT FK_TDARTemporaryReceipt_PreOrder
            FOREIGN KEY (PreOrderID) REFERENCES dbo.TDARPreOrder(PreOrderID),
        CONSTRAINT UQ_TDARTemporaryReceipt_Company_Code
            UNIQUE (CompanyID, ReceiptCode),
        CONSTRAINT CK_TDARTemporaryReceipt_OneReference
            CHECK (QuotationID IS NULL OR PreOrderID IS NULL),
        CONSTRAINT CK_TDARTemporaryReceipt_Amounts
            CHECK
            (
                ReferenceAmount >= 0
                AND PreviouslyReceivedAmount >= 0
                AND ReceivedAmount > 0
                AND BalanceAmount >= 0
            ),
        CONSTRAINT CK_TDARTemporaryReceipt_Status
            CHECK (StatusCode IN (N'DRAFT',N'CONFIRMED',N'VOID'))
    );
END;

IF OBJECT_ID(N'dbo.TDARTemporaryReceiptPayment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARTemporaryReceiptPayment
    (
        TemporaryReceiptPaymentID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDARTemporaryReceiptPayment PRIMARY KEY,
        TemporaryReceiptID bigint NOT NULL,
        [LineNo] int NOT NULL,
        PaymentMethodCode nvarchar(30) NOT NULL,
        Amount decimal(18,2) NOT NULL,
        BankCode nvarchar(30) NULL,
        BankAccountName nvarchar(200) NULL,
        ReferenceNo nvarchar(100) NULL,
        ChequeNo nvarchar(100) NULL,
        ChequeDate date NULL,
        Remark nvarchar(500) NULL,

        CONSTRAINT FK_TDARTemporaryReceiptPayment_Header
            FOREIGN KEY (TemporaryReceiptID)
            REFERENCES dbo.TDARTemporaryReceipt(TemporaryReceiptID)
            ON DELETE CASCADE,
        CONSTRAINT UQ_TDARTemporaryReceiptPayment_Line
            UNIQUE (TemporaryReceiptID, [LineNo]),
        CONSTRAINT CK_TDARTemporaryReceiptPayment_Amount CHECK (Amount > 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_TDARTemporaryReceipt_Company_Date'
      AND object_id=OBJECT_ID(N'dbo.TDARTemporaryReceipt')
)
    CREATE INDEX IX_TDARTemporaryReceipt_Company_Date
        ON dbo.TDARTemporaryReceipt(CompanyID,ReceiptDate,TemporaryReceiptID);

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_TDARTemporaryReceipt_Quotation'
      AND object_id=OBJECT_ID(N'dbo.TDARTemporaryReceipt')
)
    CREATE INDEX IX_TDARTemporaryReceipt_Quotation
        ON dbo.TDARTemporaryReceipt(CompanyID,QuotationID,StatusCode,IsActive);

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_TDARTemporaryReceipt_PreOrder'
      AND object_id=OBJECT_ID(N'dbo.TDARTemporaryReceipt')
)
    CREATE INDEX IX_TDARTemporaryReceipt_PreOrder
        ON dbo.TDARTemporaryReceipt(CompanyID,PreOrderID,StatusCode,IsActive);

COMMIT TRANSACTION;

SELECT name AS TableName
FROM sys.tables
WHERE name IN (N'TDARTemporaryReceipt',N'TDARTemporaryReceiptPayment');
