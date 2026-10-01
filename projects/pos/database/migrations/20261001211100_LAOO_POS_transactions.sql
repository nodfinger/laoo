SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'dbo.TDPOSale',N'U') IS NULL CREATE TABLE dbo.TDPOSale(
  SaleID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOSale PRIMARY KEY,CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,BranchID bigint NOT NULL,OutletID bigint NOT NULL,TerminalID bigint NOT NULL,ShiftID bigint NULL,
  ReceiptNo nvarchar(50) NOT NULL,SaleDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOSale_Date DEFAULT SYSUTCDATETIME(),CustomerID bigint NULL,CashierUserID bigint NOT NULL,
  Subtotal decimal(18,4) NOT NULL,DiscountAmount decimal(18,4) NOT NULL,TaxAmount decimal(18,4) NOT NULL,NetAmount decimal(18,4) NOT NULL,
  StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDPOSale_Status DEFAULT(N'COMPLETED'),IdempotencyKey uniqueidentifier NOT NULL,CancelReason nvarchar(1000) NULL,CancelledAt datetime2(3) NULL,CancelledBy bigint NULL,
  CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOSale_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDPOSale_Company_Receipt UNIQUE(CompanyID,ReceiptNo),CONSTRAINT UQ_TDPOSale_Idempotency UNIQUE(CompanyID,IdempotencyKey),
  CONSTRAINT FK_TDPOSale_Outlet FOREIGN KEY(OutletID) REFERENCES dbo.TDPOOutlet(OutletID),CONSTRAINT FK_TDPOSale_Terminal FOREIGN KEY(TerminalID) REFERENCES dbo.TDPOTerminal(TerminalID),CONSTRAINT FK_TDPOSale_Shift FOREIGN KEY(ShiftID) REFERENCES dbo.TDPOShift(ShiftID),
  CONSTRAINT CK_TDPOSale_Status CHECK(StatusCode IN(N'COMPLETED',N'PARTIAL_RETURN',N'RETURNED',N'CANCELLED'))
 );
 IF OBJECT_ID(N'dbo.TDPOSaleItem',N'U') IS NULL CREATE TABLE dbo.TDPOSaleItem(
  SaleItemID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOSaleItem PRIMARY KEY,CompanyID bigint NOT NULL,SaleID bigint NOT NULL,ItemID bigint NOT NULL,
  ItemCodeSnapshot nvarchar(50) NOT NULL,ItemNameSnapshot nvarchar(250) NOT NULL,Quantity decimal(18,4) NOT NULL,UnitPrice decimal(18,4) NOT NULL,DiscountAmount decimal(18,4) NOT NULL,TaxAmount decimal(18,4) NOT NULL,LineNetAmount decimal(18,4) NOT NULL,ReturnedQuantity decimal(18,4) NOT NULL CONSTRAINT DF_TDPOSaleItem_Returned DEFAULT(0),
  CONSTRAINT FK_TDPOSaleItem_Sale FOREIGN KEY(SaleID) REFERENCES dbo.TDPOSale(SaleID),CONSTRAINT CK_TDPOSaleItem_Qty CHECK(Quantity>0)
 );
 IF OBJECT_ID(N'dbo.TDPOSalePayment',N'U') IS NULL CREATE TABLE dbo.TDPOSalePayment(
  SalePaymentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOSalePayment PRIMARY KEY,CompanyID bigint NOT NULL,SaleID bigint NOT NULL,PaymentCode nvarchar(20) NOT NULL,
  Amount decimal(18,4) NOT NULL,ReceivedAmount decimal(18,4) NULL,ChangeAmount decimal(18,4) NULL,ReferenceNo nvarchar(100) NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOSalePayment_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_TDPOSalePayment_Sale FOREIGN KEY(SaleID) REFERENCES dbo.TDPOSale(SaleID),CONSTRAINT CK_TDPOSalePayment_Amount CHECK(Amount>0)
 );
 IF OBJECT_ID(N'dbo.TDPOReturn',N'U') IS NULL CREATE TABLE dbo.TDPOReturn(
  ReturnID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOReturn PRIMARY KEY,CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,BranchID bigint NOT NULL,OutletID bigint NOT NULL,TerminalID bigint NOT NULL,ShiftID bigint NULL,SaleID bigint NOT NULL,
  ReturnNo nvarchar(50) NOT NULL,ReturnDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOReturn_Date DEFAULT SYSUTCDATETIME(),RefundAmount decimal(18,4) NOT NULL,RefundPaymentCode nvarchar(20) NOT NULL,ReasonText nvarchar(1000) NOT NULL,StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDPOReturn_Status DEFAULT(N'COMPLETED'),CreateBy bigint NOT NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOReturn_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDPOReturn_Company_No UNIQUE(CompanyID,ReturnNo),CONSTRAINT FK_TDPOReturn_Sale FOREIGN KEY(SaleID) REFERENCES dbo.TDPOSale(SaleID),CONSTRAINT CK_TDPOReturn_Status CHECK(StatusCode=N'COMPLETED')
 );
 IF OBJECT_ID(N'dbo.TDPOReturnItem',N'U') IS NULL CREATE TABLE dbo.TDPOReturnItem(
  ReturnItemID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOReturnItem PRIMARY KEY,CompanyID bigint NOT NULL,ReturnID bigint NOT NULL,SaleItemID bigint NOT NULL,ItemID bigint NOT NULL,Quantity decimal(18,4) NOT NULL,RefundAmount decimal(18,4) NOT NULL,
  CONSTRAINT FK_TDPOReturnItem_Return FOREIGN KEY(ReturnID) REFERENCES dbo.TDPOReturn(ReturnID),CONSTRAINT FK_TDPOReturnItem_SaleItem FOREIGN KEY(SaleItemID) REFERENCES dbo.TDPOSaleItem(SaleItemID),CONSTRAINT CK_TDPOReturnItem_Qty CHECK(Quantity>0)
 );
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_TDPOSale_Company_Date' AND object_id=OBJECT_ID(N'dbo.TDPOSale')) CREATE INDEX IX_TDPOSale_Company_Date ON dbo.TDPOSale(CompanyID,SaleDate DESC,BranchID,OutletID,TerminalID);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_TDPOOutletItem_Outlet' AND object_id=OBJECT_ID(N'dbo.TDPOOutletItem')) CREATE INDEX IX_TDPOOutletItem_Outlet ON dbo.TDPOOutletItem(CompanyID,OutletID,IsSellable,ItemID);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
