/* ใบส่งของ + รายการสินค้า + สมุดเคลื่อนไหวสต๊อก */
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDARQuotation',N'U') IS NULL THROW 50101,N'ไม่พบ dbo.TDARQuotation',1;
IF OBJECT_ID(N'dbo.TDARPreOrder',N'U') IS NULL THROW 50102,N'ไม่พบ dbo.TDARPreOrder',1;
IF OBJECT_ID(N'dbo.TDARTemporaryReceipt',N'U') IS NULL THROW 50103,N'ไม่พบ dbo.TDARTemporaryReceipt',1;
IF OBJECT_ID(N'dbo.TDIVItem',N'U') IS NULL THROW 50104,N'ไม่พบ dbo.TDIVItem',1;

IF OBJECT_ID(N'dbo.TDARDeliveryNote',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDARDeliveryNote
 (
  DeliveryNoteID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARDeliveryNote PRIMARY KEY,
  CompanyID bigint NOT NULL,
  DeliveryCode nvarchar(30) NOT NULL,
  DeliveryDate date NOT NULL CONSTRAINT DF_TDARDeliveryNote_Date DEFAULT CONVERT(date,SYSUTCDATETIME()),
  ReferenceType nvarchar(30) NOT NULL CONSTRAINT DF_TDARDeliveryNote_ReferenceType DEFAULT(N'NONE'),
  QuotationID bigint NULL,
  PreOrderID bigint NULL,
  TemporaryReceiptID bigint NULL,
  ParentDeliveryNoteID bigint NULL,
  CustomerID bigint NOT NULL,
  CusCode nvarchar(50) NOT NULL,
  CusName nvarchar(200) NOT NULL,
  CusAddress nvarchar(1000) NULL,
  TaxID nvarchar(30) NULL,
  ContactName nvarchar(200) NULL,
  ContactPhone nvarchar(100) NULL,
  DeliveryAddress nvarchar(1000) NULL,
  TransportBy nvarchar(200) NULL,
  TrackingNo nvarchar(100) NULL,
  TotalAmount decimal(18,2) NOT NULL CONSTRAINT DF_TDARDeliveryNote_Total DEFAULT(0),
  StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDARDeliveryNote_Status DEFAULT(N'DRAFT'),
  Remark nvarchar(1000) NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDARDeliveryNote_Active DEFAULT(1),
  CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDARDeliveryNote_CreateDate DEFAULT SYSUTCDATETIME(),
  CreatedBy bigint NULL,
  UpdateDate datetime2(7) NULL,
  UpdatedBy bigint NULL,
  ConfirmDate datetime2(7) NULL,
  ConfirmedBy bigint NULL,
  VoidDate datetime2(7) NULL,
  VoidedBy bigint NULL,
  CONSTRAINT UQ_TDARDeliveryNote_Company_Code UNIQUE(CompanyID,DeliveryCode),
  CONSTRAINT FK_TDARDeliveryNote_Quotation FOREIGN KEY(QuotationID) REFERENCES dbo.TDARQuotation(QuotationID),
  CONSTRAINT FK_TDARDeliveryNote_PreOrder FOREIGN KEY(PreOrderID) REFERENCES dbo.TDARPreOrder(PreOrderID),
  CONSTRAINT FK_TDARDeliveryNote_TemporaryReceipt FOREIGN KEY(TemporaryReceiptID) REFERENCES dbo.TDARTemporaryReceipt(TemporaryReceiptID),
  CONSTRAINT FK_TDARDeliveryNote_Parent FOREIGN KEY(ParentDeliveryNoteID) REFERENCES dbo.TDARDeliveryNote(DeliveryNoteID),
  CONSTRAINT CK_TDARDeliveryNote_Status CHECK(StatusCode IN(N'DRAFT',N'CONFIRMED',N'VOID')),
  CONSTRAINT CK_TDARDeliveryNote_ReferenceType CHECK(ReferenceType IN(N'NONE',N'QUOTATION',N'PREORDER',N'TEMP_RECEIPT',N'DELIVERY_NOTE')),
  CONSTRAINT CK_TDARDeliveryNote_OneReference CHECK
  (
   (CASE WHEN QuotationID IS NULL THEN 0 ELSE 1 END +
    CASE WHEN PreOrderID IS NULL THEN 0 ELSE 1 END +
    CASE WHEN TemporaryReceiptID IS NULL THEN 0 ELSE 1 END +
    CASE WHEN ParentDeliveryNoteID IS NULL THEN 0 ELSE 1 END) <= 1
  )
 );
 CREATE INDEX IX_TDARDeliveryNote_CompanyDate ON dbo.TDARDeliveryNote(CompanyID,DeliveryDate,DeliveryNoteID);
END;

IF OBJECT_ID(N'dbo.TDARDeliveryNoteDetail',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDARDeliveryNoteDetail
 (
  DeliveryNoteDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDARDeliveryNoteDetail PRIMARY KEY,
  DeliveryNoteID bigint NOT NULL,
  [LineNo] int NOT NULL,
  QuotationDetailID bigint NULL,
  PreOrderDetailID bigint NULL,
  ParentDeliveryNoteDetailID bigint NULL,
  ItemID bigint NOT NULL,
  ItemCode nvarchar(50) NOT NULL,
  ItemName nvarchar(200) NOT NULL,
  UnitCode nvarchar(50) NOT NULL,
  OrderedQty decimal(18,4) NOT NULL CONSTRAINT DF_TDARDeliveryNoteDetail_Ordered DEFAULT(0),
  PreviouslyDeliveredQty decimal(18,4) NOT NULL CONSTRAINT DF_TDARDeliveryNoteDetail_Previous DEFAULT(0),
  DeliveryQty decimal(18,4) NOT NULL,
  UnitPrice decimal(18,4) NOT NULL CONSTRAINT DF_TDARDeliveryNoteDetail_Price DEFAULT(0),
  Amount decimal(18,4) NOT NULL CONSTRAINT DF_TDARDeliveryNoteDetail_Amount DEFAULT(0),
  Remark nvarchar(500) NULL,
  CONSTRAINT FK_TDARDeliveryNoteDetail_Header FOREIGN KEY(DeliveryNoteID) REFERENCES dbo.TDARDeliveryNote(DeliveryNoteID) ON DELETE CASCADE,
  CONSTRAINT FK_TDARDeliveryNoteDetail_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
  CONSTRAINT FK_TDARDeliveryNoteDetail_QuotationDetail FOREIGN KEY(QuotationDetailID) REFERENCES dbo.TDARQuotationDetail(QuotationDetailID),
  CONSTRAINT FK_TDARDeliveryNoteDetail_PreOrderDetail FOREIGN KEY(PreOrderDetailID) REFERENCES dbo.TDARPreOrderDetail(PreOrderDetailID),
  CONSTRAINT FK_TDARDeliveryNoteDetail_Parent FOREIGN KEY(ParentDeliveryNoteDetailID) REFERENCES dbo.TDARDeliveryNoteDetail(DeliveryNoteDetailID),
  CONSTRAINT UQ_TDARDeliveryNoteDetail_Line UNIQUE(DeliveryNoteID,[LineNo]),
  CONSTRAINT CK_TDARDeliveryNoteDetail_Qty CHECK(OrderedQty>=0 AND PreviouslyDeliveredQty>=0 AND DeliveryQty>0),
  CONSTRAINT CK_TDARDeliveryNoteDetail_Amount CHECK(UnitPrice>=0 AND Amount>=0)
 );
END;

IF OBJECT_ID(N'dbo.TDIVStockMovement',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVStockMovement
 (
  StockMovementID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVStockMovement PRIMARY KEY,
  CompanyID bigint NOT NULL,
  ItemID bigint NOT NULL,
  DocumentType nvarchar(30) NOT NULL,
  DocumentID bigint NOT NULL,
  DocumentDetailID bigint NOT NULL,
  MovementType nvarchar(20) NOT NULL,
  Quantity decimal(18,4) NOT NULL,
  MovementDate datetime2(7) NOT NULL CONSTRAINT DF_TDIVStockMovement_Date DEFAULT SYSUTCDATETIME(),
  Remark nvarchar(500) NULL,
  CreatedBy bigint NULL,
  CONSTRAINT FK_TDIVStockMovement_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
  CONSTRAINT UQ_TDIVStockMovement_Document UNIQUE(CompanyID,DocumentType,DocumentDetailID,MovementType),
  CONSTRAINT CK_TDIVStockMovement_Type CHECK(MovementType IN(N'OUT',N'REVERSAL')),
  CONSTRAINT CK_TDIVStockMovement_Qty CHECK(Quantity<>0)
 );
 CREATE INDEX IX_TDIVStockMovement_ItemDate ON dbo.TDIVStockMovement(CompanyID,ItemID,MovementDate);
END;

COMMIT TRANSACTION;
