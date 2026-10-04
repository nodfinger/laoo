SET XACT_ABORT ON;
-- New module-owned tables only. Existing School and Inventory tables are referenced, not altered.
CREATE TABLE dbo.TDSFSetting(
 -- TDSTCompanySetUp uses PKValue, not a unique CompanyID. Ownership is checked by CompanyMenuAccess.
 CompanyID bigint NOT NULL PRIMARY KEY,
 IsEnabled bit NOT NULL DEFAULT 1, CommissionEnabled bit NOT NULL DEFAULT 0,
 DefaultCommissionRate decimal(5,2) NOT NULL DEFAULT 0 CHECK(DefaultCommissionRate BETWEEN 0 AND 100),
 UpdatedBy bigint NULL, UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), Version rowversion);
CREATE TABLE dbo.TDSFShop(
 ShopID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,
 ShopCode nvarchar(30) NOT NULL,ShopName nvarchar(200) NOT NULL,
 TrackStock bit NOT NULL DEFAULT 0,WarehouseID bigint NULL REFERENCES dbo.TDIVWarehouse(WarehouseID),
 IsActive bit NOT NULL DEFAULT 1,CommissionRate decimal(5,2) NULL CHECK(CommissionRate BETWEEN 0 AND 100),
 CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),CreatedBy bigint NOT NULL,
 Version rowversion,CONSTRAINT UQ_TDSFShop_Code UNIQUE(CompanyID,ShopCode),
 CONSTRAINT UQ_TDSFShop_Company UNIQUE(CompanyID,ShopID),
 CONSTRAINT CK_TDSFShop_Warehouse CHECK(TrackStock=0 OR WarehouseID IS NOT NULL));
CREATE UNIQUE INDEX UX_TDSFShop_Warehouse ON dbo.TDSFShop(CompanyID,WarehouseID) WHERE WarehouseID IS NOT NULL;
-- One shop assignment limits a shop user even if they have broad menu permissions.
CREATE TABLE dbo.TDSFShopUser(
 CompanyID bigint NOT NULL,UserID bigint NOT NULL REFERENCES dbo.TDADUser(UserID),ShopID bigint NOT NULL,
 IsActive bit NOT NULL DEFAULT 1,PRIMARY KEY(CompanyID,UserID),
 FOREIGN KEY(CompanyID,ShopID) REFERENCES dbo.TDSFShop(CompanyID,ShopID));
CREATE TABLE dbo.TDSFShopItem(
 CompanyID bigint NOT NULL,ShopID bigint NOT NULL,ItemID bigint NOT NULL REFERENCES dbo.TDIVItem(ItemID),
 SalePrice decimal(18,2) NOT NULL CHECK(SalePrice>0),IsSellable bit NOT NULL DEFAULT 1,
 PRIMARY KEY(CompanyID,ShopID,ItemID),FOREIGN KEY(CompanyID,ShopID) REFERENCES dbo.TDSFShop(CompanyID,ShopID));
CREATE TABLE dbo.TDSFCommissionRule(
 RuleID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ShopID bigint NOT NULL,
 ItemID bigint NULL REFERENCES dbo.TDIVItem(ItemID),ItemTypeCode nvarchar(50) NULL,
 Rate decimal(5,2) NOT NULL CHECK(Rate BETWEEN 0 AND 100),Version rowversion,
 FOREIGN KEY(CompanyID,ShopID) REFERENCES dbo.TDSFShop(CompanyID,ShopID),
 CHECK((ItemID IS NOT NULL AND ItemTypeCode IS NULL) OR (ItemID IS NULL AND ItemTypeCode IS NOT NULL)));
CREATE UNIQUE INDEX UX_TDSFCommission_Item ON dbo.TDSFCommissionRule(CompanyID,ShopID,ItemID) WHERE ItemID IS NOT NULL;
CREATE UNIQUE INDEX UX_TDSFCommission_Type ON dbo.TDSFCommissionRule(CompanyID,ShopID,ItemTypeCode) WHERE ItemTypeCode IS NOT NULL;
CREATE TABLE dbo.TDSFDevice(
 DeviceID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ShopID bigint NOT NULL,DeviceCode nvarchar(100) NOT NULL,
 DeviceKind nvarchar(20) NOT NULL CHECK(DeviceKind IN(N'HID',N'QR',N'FINGERPRINT')),
 SecretHash varbinary(32) NULL,IsActive bit NOT NULL DEFAULT 1,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 UNIQUE(CompanyID,DeviceCode),UNIQUE(CompanyID,DeviceID),
 FOREIGN KEY(CompanyID,ShopID) REFERENCES dbo.TDSFShop(CompanyID,ShopID));
CREATE TABLE dbo.TDSFStudentIdentifier(
 IdentifierID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,
 StudentID bigint NOT NULL REFERENCES dbo.TDSCStudent(StudentID),
 Kind nvarchar(20) NOT NULL CHECK(Kind IN(N'CARD',N'QR',N'FINGERPRINT')),
 IdentifierHash varbinary(32) NOT NULL,DisplaySuffix nvarchar(12) NOT NULL,
 DeviceID bigint NULL,IsActive bit NOT NULL DEFAULT 1,CreatedBy bigint NOT NULL,
 CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 UNIQUE(CompanyID,Kind,IdentifierHash),
 FOREIGN KEY(CompanyID,DeviceID) REFERENCES dbo.TDSFDevice(CompanyID,DeviceID),
 CHECK(Kind<>N'FINGERPRINT' OR DeviceID IS NOT NULL));
CREATE TABLE dbo.TDSFStudentCredential(
 CompanyID bigint NOT NULL,StudentID bigint NOT NULL REFERENCES dbo.TDSCStudent(StudentID),
 PasswordHash nvarchar(500) NOT NULL,IsActive bit NOT NULL DEFAULT 1,
 FailedLoginCount int NOT NULL DEFAULT 0,LockedUntil datetime2 NULL,TokenVersion int NOT NULL DEFAULT 1,
 MustChangePassword bit NOT NULL DEFAULT 1,UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 PRIMARY KEY(CompanyID,StudentID));
CREATE TABLE dbo.TDSFGuardianAccess(
 CompanyID bigint NOT NULL,GuardianID bigint NOT NULL REFERENCES dbo.TDSCGuardian(GuardianID),
 StudentID bigint NOT NULL REFERENCES dbo.TDSCStudent(StudentID),CanViewPurchases bit NOT NULL DEFAULT 1,
 PRIMARY KEY(CompanyID,GuardianID,StudentID),
 FOREIGN KEY(StudentID,GuardianID) REFERENCES dbo.TDSCStudentGuardian(StudentID,GuardianID));
CREATE TABLE dbo.TDSFWallet(
 CompanyID bigint NOT NULL,StudentID bigint NOT NULL REFERENCES dbo.TDSCStudent(StudentID),
 Balance decimal(18,2) NOT NULL DEFAULT 0 CHECK(Balance>=0),
 Version rowversion,PRIMARY KEY(CompanyID,StudentID));
CREATE TABLE dbo.TDSFOperation(
 OperationID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,RequestKey uniqueidentifier NOT NULL,
 RequestHash varbinary(32) NOT NULL,ActionCode nvarchar(30) NOT NULL,ActorID bigint NOT NULL,
 ResultJson nvarchar(max) NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 UNIQUE(CompanyID,RequestKey));
CREATE TABLE dbo.TDSFSale(
 SaleID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ShopID bigint NOT NULL,
 StudentID bigint NOT NULL REFERENCES dbo.TDSCStudent(StudentID),OperationID bigint NOT NULL REFERENCES dbo.TDSFOperation(OperationID),
 ReceiptNo nvarchar(50) NOT NULL,ClassroomID bigint NOT NULL,LevelID bigint NOT NULL,ClassroomSnapshot nvarchar(150) NOT NULL,
 TrackStock bit NOT NULL,WarehouseID bigint NULL REFERENCES dbo.TDIVWarehouse(WarehouseID),
 TotalAmount decimal(18,2) NOT NULL CHECK(TotalAmount>0),RefundedAmount decimal(18,2) NOT NULL DEFAULT 0,
 CommissionAmount decimal(18,2) NOT NULL CHECK(CommissionAmount>=0),RefundedCommission decimal(18,2) NOT NULL DEFAULT 0,
 CreatedBy bigint NOT NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 UNIQUE(CompanyID,SaleID),UNIQUE(CompanyID,ReceiptNo),UNIQUE(OperationID),
 FOREIGN KEY(CompanyID,ShopID) REFERENCES dbo.TDSFShop(CompanyID,ShopID),
 CHECK(RefundedAmount BETWEEN 0 AND TotalAmount),CHECK(RefundedCommission BETWEEN 0 AND CommissionAmount));
CREATE TABLE dbo.TDSFSaleItem(
 SaleItemID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,SaleID bigint NOT NULL,
 ItemID bigint NOT NULL REFERENCES dbo.TDIVItem(ItemID),ItemNameSnapshot nvarchar(255) NOT NULL,
 ItemTypeSnapshot nvarchar(50) NULL,Quantity int NOT NULL CHECK(Quantity>0),ReturnedQuantity int NOT NULL DEFAULT 0,
 UnitPrice decimal(18,2) NOT NULL CHECK(UnitPrice>0),DiscountAmount decimal(18,2) NOT NULL DEFAULT 0,
 NetAmount decimal(18,2) NOT NULL CHECK(NetAmount>0),
 CommissionRate decimal(5,2) NOT NULL CHECK(CommissionRate BETWEEN 0 AND 100),
 CommissionAmount decimal(18,2) NOT NULL CHECK(CommissionAmount>=0),
 UNIQUE(CompanyID,SaleItemID),UNIQUE(CompanyID,SaleID,ItemID),
 FOREIGN KEY(CompanyID,SaleID) REFERENCES dbo.TDSFSale(CompanyID,SaleID),
 CHECK(ReturnedQuantity BETWEEN 0 AND Quantity),CHECK(DiscountAmount BETWEEN 0 AND Quantity*UnitPrice));
CREATE TABLE dbo.TDSFRefund(
 RefundID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,SaleID bigint NOT NULL,
 OperationID bigint NOT NULL REFERENCES dbo.TDSFOperation(OperationID),
 Reason nvarchar(500) NOT NULL,Amount decimal(18,2) NOT NULL CHECK(Amount>0),
 CommissionAmount decimal(18,2) NOT NULL CHECK(CommissionAmount>=0),
 CreatedBy bigint NOT NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 UNIQUE(CompanyID,RefundID),UNIQUE(OperationID),
 FOREIGN KEY(CompanyID,SaleID) REFERENCES dbo.TDSFSale(CompanyID,SaleID));
CREATE TABLE dbo.TDSFRefundItem(
 CompanyID bigint NOT NULL,RefundID bigint NOT NULL,SaleItemID bigint NOT NULL,
 Quantity int NOT NULL CHECK(Quantity>0),Amount decimal(18,2) NOT NULL CHECK(Amount>0),
 CommissionAmount decimal(18,2) NOT NULL CHECK(CommissionAmount>=0),
 PRIMARY KEY(CompanyID,RefundID,SaleItemID),
 FOREIGN KEY(CompanyID,RefundID) REFERENCES dbo.TDSFRefund(CompanyID,RefundID),
 FOREIGN KEY(CompanyID,SaleItemID) REFERENCES dbo.TDSFSaleItem(CompanyID,SaleItemID));
CREATE TABLE dbo.TDSFWalletLedger(
 LedgerID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,StudentID bigint NOT NULL,
 OperationID bigint NOT NULL REFERENCES dbo.TDSFOperation(OperationID),
 EntryType nvarchar(20) NOT NULL CHECK(EntryType IN(N'TOPUP',N'ADJUST',N'SALE',N'REFUND')),
 Amount decimal(18,2) NOT NULL CHECK(Amount<>0),BalanceAfter decimal(18,2) NOT NULL CHECK(BalanceAfter>=0),
 ReferenceNo nvarchar(100) NOT NULL,Reason nvarchar(500) NULL,PaymentMethod nvarchar(20) NULL,
 CreatedBy bigint NOT NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 UNIQUE(OperationID),FOREIGN KEY(CompanyID,StudentID) REFERENCES dbo.TDSFWallet(CompanyID,StudentID));
CREATE INDEX IX_TDSFWalletLedger_Student ON dbo.TDSFWalletLedger(CompanyID,StudentID,LedgerID DESC);
CREATE INDEX IX_TDSFSale_Report ON dbo.TDSFSale(CompanyID,ShopID,CreatedAt DESC);
CREATE INDEX IX_TDSFSale_Student ON dbo.TDSFSale(CompanyID,StudentID,CreatedAt DESC);
CREATE TABLE dbo.TDSFTransfer(
 TransferID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ShopID bigint NOT NULL,
 SourceWarehouseID bigint NOT NULL REFERENCES dbo.TDIVWarehouse(WarehouseID),
 TargetWarehouseID bigint NOT NULL REFERENCES dbo.TDIVWarehouse(WarehouseID),
 StatusCode nvarchar(20) NOT NULL DEFAULT N'DRAFT' CHECK(StatusCode IN(N'DRAFT',N'SENT',N'RECEIVED',N'CANCELLED')),
 ReferenceNo nvarchar(100) NOT NULL,CreatedBy bigint NOT NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 SentAt datetime2 NULL,ReceivedAt datetime2 NULL,ReceivedBy bigint NULL,Version rowversion,
 UNIQUE(CompanyID,TransferID),FOREIGN KEY(CompanyID,ShopID) REFERENCES dbo.TDSFShop(CompanyID,ShopID),
 CHECK(SourceWarehouseID<>TargetWarehouseID));
CREATE TABLE dbo.TDSFTransferItem(
 TransferItemID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,TransferID bigint NOT NULL,
 ItemID bigint NOT NULL REFERENCES dbo.TDIVItem(ItemID),Quantity decimal(18,4) NOT NULL CHECK(Quantity>0),
 UNIQUE(CompanyID,TransferID,ItemID),
 FOREIGN KEY(CompanyID,TransferID) REFERENCES dbo.TDSFTransfer(CompanyID,TransferID));
CREATE TABLE dbo.TDSFSettlement(
 SettlementID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ShopID bigint NOT NULL,
 PeriodStart date NOT NULL,PeriodEnd date NOT NULL,SalesAmount decimal(18,2) NOT NULL,
 RefundAmount decimal(18,2) NOT NULL,CommissionAmount decimal(18,2) NOT NULL,NetAmount decimal(18,2) NOT NULL,
 CreatedBy bigint NOT NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 FOREIGN KEY(CompanyID,ShopID) REFERENCES dbo.TDSFShop(CompanyID,ShopID),
 CHECK(PeriodEnd>=PeriodStart),UNIQUE(CompanyID,ShopID,PeriodStart,PeriodEnd));
CREATE TABLE dbo.TDSFAudit(
 AuditID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,UserID bigint NOT NULL,
 ActionCode nvarchar(30) NOT NULL,EntityType nvarchar(50) NOT NULL,EntityID bigint NOT NULL,
 DetailJson nvarchar(max) NULL,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
GO
CREATE TRIGGER dbo.TR_TDSFWalletLedger_AppendOnly ON dbo.TDSFWalletLedger
INSTEAD OF UPDATE,DELETE AS
BEGIN
 THROW 57305,N'Wallet ledger is append-only. Post a compensating adjustment instead.',1;
END;
