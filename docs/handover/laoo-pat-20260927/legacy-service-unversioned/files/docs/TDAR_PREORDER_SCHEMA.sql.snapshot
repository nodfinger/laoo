/*
    โครงสร้างใบรับจองสินค้า Pre-order

    Flow:
      TDARQuotation -> TDARPreOrder -> ใบเสร็จชั่วคราว/ใบส่งของ/ใบกำกับภาษี

    StatusCode ที่แนะนำ:
      DRAFT, CONFIRMED, WAITING_STOCK, PARTIAL_STOCK,
      READY, DELIVERED, CANCELLED, CLOSED

    Quantity       = จำนวนที่ลูกค้าจอง
    AllocatedQty   = จำนวนที่จัดสรรได้เมื่อสินค้าเข้าสต๊อก
    DeliveredQty   = จำนวนที่ส่งมอบแล้ว
*/

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDARQuotation', N'U') IS NULL
    THROW 50001, 'ไม่พบตาราง dbo.TDARQuotation กรุณาสร้างใบเสนอราคาก่อน', 1;

IF OBJECT_ID(N'dbo.TDARQuotationDetail', N'U') IS NULL
    THROW 50002, 'ไม่พบตาราง dbo.TDARQuotationDetail กรุณาสร้างรายการใบเสนอราคาก่อน', 1;

IF OBJECT_ID(N'dbo.TDIVItem', N'U') IS NULL
    THROW 50003, 'ไม่พบตาราง dbo.TDIVItem กรุณาสร้างตารางสินค้าก่อน', 1;

IF OBJECT_ID(N'dbo.TDARPreOrder', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARPreOrder
    (
        PreOrderID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDARPreOrder PRIMARY KEY,
        CompanyID bigint NOT NULL,
        PreOrderCode nvarchar(30) NOT NULL,
        PreOrderDate date NOT NULL
            CONSTRAINT DF_TDARPreOrder_PreOrderDate DEFAULT CONVERT(date, SYSUTCDATETIME()),
        QuotationID bigint NOT NULL,
        CustomerID bigint NOT NULL,
        CusCode nvarchar(50) NOT NULL,
        CusName nvarchar(200) NOT NULL,
        ContactName nvarchar(200) NULL,
        ContactPhone nvarchar(50) NULL,
        ExpectedDate date NULL,
        TotalAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARPreOrder_TotalAmount DEFAULT (0),
        DepositAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARPreOrder_DepositAmount DEFAULT (0),
        PaidAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARPreOrder_PaidAmount DEFAULT (0),
        BalanceAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_TDARPreOrder_BalanceAmount DEFAULT (0),
        StatusCode nvarchar(30) NOT NULL
            CONSTRAINT DF_TDARPreOrder_StatusCode DEFAULT (N'DRAFT'),
        Remark nvarchar(1000) NULL,
        IsActive bit NOT NULL
            CONSTRAINT DF_TDARPreOrder_IsActive DEFAULT (1),
        CreateDate datetime2(7) NOT NULL
            CONSTRAINT DF_TDARPreOrder_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(7) NULL,
        UpdatedBy bigint NULL,

        CONSTRAINT FK_TDARPreOrder_Quotation
            FOREIGN KEY (QuotationID)
            REFERENCES dbo.TDARQuotation(QuotationID),
        CONSTRAINT UQ_TDARPreOrder_Company_PreOrderCode
            UNIQUE (CompanyID, PreOrderCode),
        CONSTRAINT CK_TDARPreOrder_Amounts
            CHECK
            (
                TotalAmount >= 0
                AND DepositAmount >= 0
                AND PaidAmount >= 0
                AND BalanceAmount >= 0
            )
    );
END;

IF OBJECT_ID(N'dbo.TDARPreOrderDetail', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARPreOrderDetail
    (
        PreOrderDetailID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDARPreOrderDetail PRIMARY KEY,
        PreOrderID bigint NOT NULL,
        [LineNo] int NOT NULL,
        QuotationDetailID bigint NULL,
        ItemID bigint NOT NULL,
        ItemCode nvarchar(50) NOT NULL,
        ItemName nvarchar(200) NOT NULL,
        UnitCode nvarchar(50) NULL,
        Quantity decimal(18,4) NOT NULL,
        AllocatedQty decimal(18,4) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_AllocatedQty DEFAULT (0),
        DeliveredQty decimal(18,4) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_DeliveredQty DEFAULT (0),
        UnitPrice decimal(18,4) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_UnitPrice DEFAULT (0),
        DiscountType nvarchar(1) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_DiscountType DEFAULT (N'N'),
        BeforeDiscount decimal(18,4) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_BeforeDiscount DEFAULT (0),
        DiscountPercent decimal(9,4) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_DiscountPercent DEFAULT (0),
        DiscountAmount decimal(18,4) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_DiscountAmount DEFAULT (0),
        Amount decimal(18,4) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_Amount DEFAULT (0),
        StatusCode nvarchar(30) NOT NULL
            CONSTRAINT DF_TDARPreOrderDetail_StatusCode DEFAULT (N'WAITING_STOCK'),
        Remark nvarchar(500) NULL,

        CONSTRAINT FK_TDARPreOrderDetail_PreOrder
            FOREIGN KEY (PreOrderID)
            REFERENCES dbo.TDARPreOrder(PreOrderID)
            ON DELETE CASCADE,
        CONSTRAINT FK_TDARPreOrderDetail_QuotationDetail
            FOREIGN KEY (QuotationDetailID)
            REFERENCES dbo.TDARQuotationDetail(QuotationDetailID),
        CONSTRAINT FK_TDARPreOrderDetail_Item
            FOREIGN KEY (ItemID)
            REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT UQ_TDARPreOrderDetail_Line
            UNIQUE (PreOrderID, [LineNo]),
        CONSTRAINT CK_TDARPreOrderDetail_DiscountType
            CHECK (DiscountType IN (N'N', N'P', N'A')),
        CONSTRAINT CK_TDARPreOrderDetail_Quantity
            CHECK
            (
                Quantity > 0
                AND AllocatedQty >= 0
                AND DeliveredQty >= 0
                AND AllocatedQty <= Quantity
                AND DeliveredQty <= AllocatedQty
            ),
        CONSTRAINT CK_TDARPreOrderDetail_Discount
            CHECK
            (
                DiscountPercent >= 0
                AND DiscountPercent <= 100
                AND DiscountAmount >= 0
                AND DiscountAmount <= BeforeDiscount
                AND Amount = BeforeDiscount - DiscountAmount
            )
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_TDARPreOrder_Company_Status_Date'
      AND object_id = OBJECT_ID(N'dbo.TDARPreOrder')
)
BEGIN
    CREATE INDEX IX_TDARPreOrder_Company_Status_Date
        ON dbo.TDARPreOrder (CompanyID, StatusCode, PreOrderDate, PreOrderID);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_TDARPreOrder_Quotation'
      AND object_id = OBJECT_ID(N'dbo.TDARPreOrder')
)
BEGIN
    CREATE INDEX IX_TDARPreOrder_Quotation
        ON dbo.TDARPreOrder (CompanyID, QuotationID, IsActive);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_TDARPreOrderDetail_Item'
      AND object_id = OBJECT_ID(N'dbo.TDARPreOrderDetail')
)
BEGIN
    CREATE INDEX IX_TDARPreOrderDetail_Item
        ON dbo.TDARPreOrderDetail (ItemID, StatusCode, PreOrderID);
END;

COMMIT TRANSACTION;

SELECT name AS TableName
FROM sys.tables
WHERE name IN (N'TDARPreOrder', N'TDARPreOrderDetail');
