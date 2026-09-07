SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @LockResult int;
EXEC @LockResult=sys.sp_getapplock @Resource=N'LAOO_SCHEMA_MIGRATION',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=60000;
IF @LockResult<0 THROW 52300,N'Unable to acquire LAOO schema migration lock',1;

IF OBJECT_ID(N'dbo.TDSTSchemaMigration',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTSchemaMigration
    (
        ProjectCode nvarchar(30) NOT NULL,
        MigrationCode nvarchar(100) NOT NULL,
        Checksum varbinary(32) NOT NULL,
        AppliedDate datetime2(3) NOT NULL CONSTRAINT DF_TDSTSchemaMigration_AppliedDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TDSTSchemaMigration PRIMARY KEY(ProjectCode,MigrationCode)
    );
END;

IF EXISTS(SELECT 1 FROM dbo.TDSTSchemaMigration WHERE ProjectCode=N'LAOO_SERVICE' AND MigrationCode=N'20260907090000')
BEGIN
    COMMIT TRANSACTION;
    RETURN;
END;

IF COL_LENGTH(N'dbo.TDIVItem', N'ItemKindCode') IS NULL
    ALTER TABLE dbo.TDIVItem ADD ItemKindCode nvarchar(20) NULL;
IF COL_LENGTH(N'dbo.TDIVItem', N'StockTrackingCode') IS NULL
    ALTER TABLE dbo.TDIVItem ADD StockTrackingCode nvarchar(20) NULL;

UPDATE dbo.TDIVItem
SET ItemKindCode = COALESCE(ItemKindCode, N'GOODS'),
    StockTrackingCode = COALESCE(StockTrackingCode, N'QUANTITY')
WHERE ItemKindCode IS NULL OR StockTrackingCode IS NULL;

ALTER TABLE dbo.TDIVItem ALTER COLUMN ItemKindCode nvarchar(20) NOT NULL;
ALTER TABLE dbo.TDIVItem ALTER COLUMN StockTrackingCode nvarchar(20) NOT NULL;

IF OBJECT_ID(N'dbo.CK_TDIVItem_ItemKindCode', N'C') IS NULL
    ALTER TABLE dbo.TDIVItem ADD CONSTRAINT CK_TDIVItem_ItemKindCode
        CHECK (ItemKindCode IN (N'GOODS', N'SERVICE'));
IF OBJECT_ID(N'dbo.CK_TDIVItem_StockTrackingCode', N'C') IS NULL
    ALTER TABLE dbo.TDIVItem ADD CONSTRAINT CK_TDIVItem_StockTrackingCode
        CHECK (StockTrackingCode IN (N'NONE', N'QUANTITY', N'SERIAL'));
IF OBJECT_ID(N'dbo.CK_TDIVItem_KindTracking', N'C') IS NULL
    ALTER TABLE dbo.TDIVItem ADD CONSTRAINT CK_TDIVItem_KindTracking
        CHECK (ItemKindCode = N'GOODS' OR StockTrackingCode = N'NONE');

IF OBJECT_ID(N'dbo.TDIVItemUsage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemUsage
    (
        ItemUsageID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVItemUsage PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ItemID bigint NOT NULL,
        UsageCode nvarchar(30) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVItemUsage_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        CONSTRAINT FK_TDIVItemUsage_Item FOREIGN KEY (ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT UQ_TDIVItemUsage_Company_Item_Usage UNIQUE (CompanyID, ItemID, UsageCode),
        CONSTRAINT CK_TDIVItemUsage_Code CHECK (UsageCode IN (N'SALE',N'MATERIAL',N'EQUIPMENT',N'SPARE_PART'))
    );
    CREATE INDEX IX_TDIVItemUsage_Company_Usage_Item ON dbo.TDIVItemUsage(CompanyID,UsageCode,ItemID);
END;

INSERT dbo.TDIVItemUsage(CompanyID,ItemID,UsageCode)
SELECT I.CompanyID,I.ItemID,N'SALE'
FROM dbo.TDIVItem I
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDIVItemUsage U
    WHERE U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID
);

IF OBJECT_ID(N'dbo.TDIVWarehouse', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVWarehouse
    (
        WarehouseID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVWarehouse PRIMARY KEY,
        CompanyID bigint NOT NULL,
        BranchID bigint NOT NULL,
        WarehouseCode nvarchar(50) NOT NULL,
        WarehouseName nvarchar(200) NOT NULL,
        IsDefault bit NOT NULL CONSTRAINT DF_TDIVWarehouse_IsDefault DEFAULT(0),
        IsActive bit NOT NULL CONSTRAINT DF_TDIVWarehouse_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVWarehouse_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdatedBy bigint NULL,
        CONSTRAINT UQ_TDIVWarehouse_Company_Code UNIQUE(CompanyID,WarehouseCode)
    );
    CREATE UNIQUE INDEX UX_TDIVWarehouse_Company_Default ON dbo.TDIVWarehouse(CompanyID) WHERE IsDefault=1 AND IsActive=1;
    CREATE INDEX IX_TDIVWarehouse_Company_Branch ON dbo.TDIVWarehouse(CompanyID,BranchID,IsActive);
END;

IF OBJECT_ID(N'dbo.TDIVStockBalance', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockBalance
    (
        CompanyID bigint NOT NULL,
        WarehouseID bigint NOT NULL,
        ItemID bigint NOT NULL,
        Quantity decimal(18,4) NOT NULL CONSTRAINT DF_TDIVStockBalance_Quantity DEFAULT(0),
        UpdateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVStockBalance_UpdateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TDIVStockBalance PRIMARY KEY(CompanyID,WarehouseID,ItemID),
        CONSTRAINT FK_TDIVStockBalance_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
        CONSTRAINT FK_TDIVStockBalance_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT CK_TDIVStockBalance_NonNegative CHECK(Quantity>=0)
    );
    CREATE INDEX IX_TDIVStockBalance_Company_Item ON dbo.TDIVStockBalance(CompanyID,ItemID);
END;

IF OBJECT_ID(N'dbo.TDIVStockMovement', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockMovement
    (
        StockMovementID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVStockMovement PRIMARY KEY,
        CompanyID bigint NOT NULL,
        WarehouseID bigint NOT NULL,
        ToWarehouseID bigint NULL,
        ItemID bigint NOT NULL,
        ItemInstanceID bigint NULL,
        DocumentType nvarchar(30) NOT NULL,
        DocumentID bigint NOT NULL,
        DocumentDetailID bigint NOT NULL,
        MovementType nvarchar(30) NOT NULL,
        Quantity decimal(18,4) NOT NULL,
        MovementDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVStockMovement_Date DEFAULT SYSUTCDATETIME(),
        ReversalOfMovementID bigint NULL,
        Remark nvarchar(500) NULL,
        CreatedBy bigint NULL,
        CONSTRAINT FK_TDIVStockMovement_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
        CONSTRAINT FK_TDIVStockMovement_ToWarehouse FOREIGN KEY(ToWarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
        CONSTRAINT FK_TDIVStockMovement_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT FK_TDIVStockMovement_Reversal FOREIGN KEY(ReversalOfMovementID) REFERENCES dbo.TDIVStockMovement(StockMovementID),
        CONSTRAINT CK_TDIVStockMovement_Type CHECK(MovementType IN(N'OPENING',N'RECEIPT',N'ISSUE',N'SALE_OUT',N'TRANSFER_IN',N'TRANSFER_OUT',N'ADJUST',N'REVERSAL')),
        CONSTRAINT CK_TDIVStockMovement_Quantity CHECK(Quantity<>0)
    );
END
ELSE
BEGIN
    IF COL_LENGTH(N'dbo.TDIVStockMovement',N'WarehouseID') IS NULL ALTER TABLE dbo.TDIVStockMovement ADD WarehouseID bigint NULL;
    IF COL_LENGTH(N'dbo.TDIVStockMovement',N'ToWarehouseID') IS NULL ALTER TABLE dbo.TDIVStockMovement ADD ToWarehouseID bigint NULL;
    IF COL_LENGTH(N'dbo.TDIVStockMovement',N'ItemInstanceID') IS NULL ALTER TABLE dbo.TDIVStockMovement ADD ItemInstanceID bigint NULL;
    IF COL_LENGTH(N'dbo.TDIVStockMovement',N'ReversalOfMovementID') IS NULL ALTER TABLE dbo.TDIVStockMovement ADD ReversalOfMovementID bigint NULL;
    IF OBJECT_ID(N'dbo.CK_TDIVStockMovement_Type',N'C') IS NOT NULL ALTER TABLE dbo.TDIVStockMovement DROP CONSTRAINT CK_TDIVStockMovement_Type;
    UPDATE dbo.TDIVStockMovement SET MovementType=N'SALE_OUT' WHERE MovementType=N'OUT';
    ALTER TABLE dbo.TDIVStockMovement ADD CONSTRAINT CK_TDIVStockMovement_Type CHECK(MovementType IN(N'OPENING',N'RECEIPT',N'ISSUE',N'SALE_OUT',N'TRANSFER_IN',N'TRANSFER_OUT',N'ADJUST',N'REVERSAL'));
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDIVStockMovement') AND name=N'IX_TDIVStockMovement_Warehouse_Item_Date')
    CREATE INDEX IX_TDIVStockMovement_Warehouse_Item_Date ON dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,MovementDate);

IF OBJECT_ID(N'dbo.TDIVStockReceipt', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockReceipt
    (
        StockReceiptID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVStockReceipt PRIMARY KEY,
        CompanyID bigint NOT NULL,
        WarehouseID bigint NOT NULL,
        ReceiptCode nvarchar(30) NOT NULL,
        ReceiptDate date NOT NULL,
        ReceiptType nvarchar(20) NOT NULL,
        StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDIVStockReceipt_Status DEFAULT(N'DRAFT'),
        ReferenceNo nvarchar(100) NULL,
        Remark nvarchar(1000) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDIVStockReceipt_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVStockReceipt_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdatedBy bigint NULL,
        ConfirmDate datetime2(3) NULL,
        ConfirmedBy bigint NULL,
        VoidDate datetime2(3) NULL,
        VoidedBy bigint NULL,
        CONSTRAINT FK_TDIVStockReceipt_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
        CONSTRAINT UQ_TDIVStockReceipt_Company_Code UNIQUE(CompanyID,ReceiptCode),
        CONSTRAINT CK_TDIVStockReceipt_Type CHECK(ReceiptType IN(N'RECEIPT',N'OPENING')),
        CONSTRAINT CK_TDIVStockReceipt_Status CHECK(StatusCode IN(N'DRAFT',N'CONFIRMED',N'VOID'))
    );
END;

IF OBJECT_ID(N'dbo.TDIVStockReceiptDetail', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockReceiptDetail
    (
        StockReceiptDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVStockReceiptDetail PRIMARY KEY,
        StockReceiptID bigint NOT NULL,
        LineNo int NOT NULL,
        ItemID bigint NOT NULL,
        Quantity decimal(18,4) NOT NULL,
        UnitCost decimal(18,4) NOT NULL CONSTRAINT DF_TDIVStockReceiptDetail_UnitCost DEFAULT(0),
        Remark nvarchar(500) NULL,
        CONSTRAINT FK_TDIVStockReceiptDetail_Header FOREIGN KEY(StockReceiptID) REFERENCES dbo.TDIVStockReceipt(StockReceiptID) ON DELETE CASCADE,
        CONSTRAINT FK_TDIVStockReceiptDetail_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT UQ_TDIVStockReceiptDetail_Line UNIQUE(StockReceiptID,LineNo),
        CONSTRAINT CK_TDIVStockReceiptDetail_Quantity CHECK(Quantity>0),
        CONSTRAINT CK_TDIVStockReceiptDetail_UnitCost CHECK(UnitCost>=0)
    );
END;

IF OBJECT_ID(N'dbo.TDIVItemInstance', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemInstance
    (
        ItemInstanceID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVItemInstance PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ItemID bigint NOT NULL,
        SerialNo nvarchar(200) NOT NULL,
        StatusCode nvarchar(20) NOT NULL,
        WarehouseID bigint NULL,
        CustomerID bigint NULL,
        BranchID bigint NULL,
        BuildingID bigint NULL,
        FloorID bigint NULL,
        RoomID bigint NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVItemInstance_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdatedBy bigint NULL,
        CONSTRAINT FK_TDIVItemInstance_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT FK_TDIVItemInstance_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
        CONSTRAINT UQ_TDIVItemInstance_Company_Serial UNIQUE(CompanyID,SerialNo),
        CONSTRAINT CK_TDIVItemInstance_Status CHECK(StatusCode IN(N'IN_STOCK',N'RESERVED',N'ISSUED',N'SOLD',N'INSTALLED',N'REPAIR',N'RETIRED'))
    );
    CREATE INDEX IX_TDIVItemInstance_Company_Item_Status ON dbo.TDIVItemInstance(CompanyID,ItemID,StatusCode);
END;

IF OBJECT_ID(N'dbo.TDIVItemInstanceHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemInstanceHistory
    (
        ItemInstanceHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVItemInstanceHistory PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ItemInstanceID bigint NOT NULL,
        FromStatusCode nvarchar(20) NULL,
        ToStatusCode nvarchar(20) NOT NULL,
        WarehouseID bigint NULL,
        CustomerID bigint NULL,
        BranchID bigint NULL,
        BuildingID bigint NULL,
        FloorID bigint NULL,
        RoomID bigint NULL,
        DocumentType nvarchar(30) NOT NULL,
        DocumentID bigint NOT NULL,
        DocumentDetailID bigint NOT NULL,
        EventDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVItemInstanceHistory_EventDate DEFAULT SYSUTCDATETIME(),
        Remark nvarchar(500) NULL,
        CreatedBy bigint NULL,
        CONSTRAINT FK_TDIVItemInstanceHistory_Instance FOREIGN KEY(ItemInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID)
    );
    CREATE INDEX IX_TDIVItemInstanceHistory_Instance_Date ON dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,EventDate);
END;

IF OBJECT_ID(N'dbo.TDIVStockReceiptSerial', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockReceiptSerial
    (
        StockReceiptSerialID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVStockReceiptSerial PRIMARY KEY,
        StockReceiptDetailID bigint NOT NULL,
        SerialNo nvarchar(200) NOT NULL,
        CONSTRAINT FK_TDIVStockReceiptSerial_Detail FOREIGN KEY(StockReceiptDetailID) REFERENCES dbo.TDIVStockReceiptDetail(StockReceiptDetailID) ON DELETE CASCADE,
        CONSTRAINT UQ_TDIVStockReceiptSerial_Detail_Serial UNIQUE(StockReceiptDetailID,SerialNo)
    );
END;

IF OBJECT_ID(N'dbo.TDIVInventoryFulfillment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVInventoryFulfillment
    (
        InventoryFulfillmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVInventoryFulfillment PRIMARY KEY,
        CompanyID bigint NOT NULL,
        SourceDocumentType nvarchar(30) NOT NULL,
        SourceDocumentDetailID bigint NOT NULL,
        ItemID bigint NOT NULL,
        WarehouseID bigint NOT NULL,
        Quantity decimal(18,4) NOT NULL,
        FulfilledByDocumentType nvarchar(30) NOT NULL,
        FulfilledByDocumentID bigint NOT NULL,
        FulfilledByDocumentDetailID bigint NOT NULL,
        ReversedDate datetime2(3) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVInventoryFulfillment_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        CONSTRAINT FK_TDIVInventoryFulfillment_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT FK_TDIVInventoryFulfillment_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
        CONSTRAINT UQ_TDIVInventoryFulfillment_Source UNIQUE(CompanyID,SourceDocumentType,SourceDocumentDetailID),
        CONSTRAINT UQ_TDIVInventoryFulfillment_Destination UNIQUE(CompanyID,FulfilledByDocumentType,FulfilledByDocumentDetailID),
        CONSTRAINT CK_TDIVInventoryFulfillment_Quantity CHECK(Quantity>0)
    );
END;

IF COL_LENGTH(N'dbo.TDARDeliveryNoteDetail',N'WarehouseID') IS NULL
    ALTER TABLE dbo.TDARDeliveryNoteDetail ADD WarehouseID bigint NULL;
IF COL_LENGTH(N'dbo.TDARTaxInvoiceDetail',N'WarehouseID') IS NULL
    ALTER TABLE dbo.TDARTaxInvoiceDetail ADD WarehouseID bigint NULL;

IF OBJECT_ID(N'dbo.TDIVDocumentSerialSelection',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVDocumentSerialSelection
    (
        CompanyID bigint NOT NULL,
        DocumentType nvarchar(30) NOT NULL,
        DocumentDetailID bigint NOT NULL,
        ItemInstanceID bigint NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVDocumentSerialSelection_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        CONSTRAINT PK_TDIVDocumentSerialSelection PRIMARY KEY(CompanyID,DocumentType,DocumentDetailID,ItemInstanceID),
        CONSTRAINT FK_TDIVDocumentSerialSelection_Instance FOREIGN KEY(ItemInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID)
    );
END;

IF OBJECT_ID(N'dbo.TDIVStockIssue',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockIssue
    (
        StockIssueID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVStockIssue PRIMARY KEY,
        CompanyID bigint NOT NULL,WarehouseID bigint NOT NULL,IssueCode nvarchar(30) NOT NULL,
        IssueDate date NOT NULL,WorkOrderID bigint NOT NULL,WorkOrderCode nvarchar(50) NOT NULL,
        StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDIVStockIssue_Status DEFAULT N'DRAFT',
        Remark nvarchar(1000) NULL,IsActive bit NOT NULL CONSTRAINT DF_TDIVStockIssue_IsActive DEFAULT 1,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVStockIssue_CreateDate DEFAULT SYSUTCDATETIME(),CreatedBy bigint NULL,
        UpdateDate datetime2(3) NULL,UpdatedBy bigint NULL,ConfirmDate datetime2(3) NULL,ConfirmedBy bigint NULL,
        VoidDate datetime2(3) NULL,VoidedBy bigint NULL,
        CONSTRAINT UQ_TDIVStockIssue_Company_Code UNIQUE(CompanyID,IssueCode),
        CONSTRAINT FK_TDIVStockIssue_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
        CONSTRAINT CK_TDIVStockIssue_Status CHECK(StatusCode IN(N'DRAFT',N'CONFIRMED',N'VOID'))
    );
END;
IF OBJECT_ID(N'dbo.TDIVStockIssueDetail',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockIssueDetail
    (
        StockIssueDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVStockIssueDetail PRIMARY KEY,
        StockIssueID bigint NOT NULL,LineNo int NOT NULL,ItemID bigint NOT NULL,Quantity decimal(18,4) NOT NULL,
        Remark nvarchar(500) NULL,
        CONSTRAINT FK_TDIVStockIssueDetail_Header FOREIGN KEY(StockIssueID) REFERENCES dbo.TDIVStockIssue(StockIssueID) ON DELETE CASCADE,
        CONSTRAINT FK_TDIVStockIssueDetail_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT UQ_TDIVStockIssueDetail_Line UNIQUE(StockIssueID,LineNo),
        CONSTRAINT CK_TDIVStockIssueDetail_Quantity CHECK(Quantity>0)
    );
END;
IF OBJECT_ID(N'dbo.TDIVStockIssueSerial',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVStockIssueSerial
    (
        StockIssueDetailID bigint NOT NULL,ItemInstanceID bigint NOT NULL,
        CONSTRAINT PK_TDIVStockIssueSerial PRIMARY KEY(StockIssueDetailID,ItemInstanceID),
        CONSTRAINT FK_TDIVStockIssueSerial_Detail FOREIGN KEY(StockIssueDetailID) REFERENCES dbo.TDIVStockIssueDetail(StockIssueDetailID) ON DELETE CASCADE,
        CONSTRAINT FK_TDIVStockIssueSerial_Instance FOREIGN KEY(ItemInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID)
    );
END;

INSERT dbo.TDSTSchemaMigration(ProjectCode,MigrationCode,Checksum)
VALUES(N'LAOO_SERVICE',N'20260907090000',HASHBYTES('SHA2_256',N'central-item-inventory-v1'));

COMMIT TRANSACTION;
