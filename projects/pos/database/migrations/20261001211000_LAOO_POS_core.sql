SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_POS' AND IsActive=1);
 IF @ProjectID IS NULL THROW 56600,N'Active LAOO_POS project is required.',1;

 IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemPOS',N'IsEnabled') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemPOS ADD IsEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemPOS_IsEnabled DEFAULT(1);
 IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemPOS',N'RequireOpenShift') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemPOS ADD RequireOpenShift bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemPOS_RequireOpenShift DEFAULT(1);
 IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemPOS',N'AllowNegativeStock') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemPOS ADD AllowNegativeStock bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemPOS_AllowNegativeStock DEFAULT(0);
 IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemPOS',N'TaxPercent') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemPOS ADD TaxPercent decimal(5,2) NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemPOS_Tax DEFAULT(7);
 IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemPOS',N'ReceiptPrefix') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemPOS ADD ReceiptPrefix nvarchar(10) NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemPOS_Prefix DEFAULT(N'POS');
 IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemPOS',N'DefaultPaymentCode') IS NULL ALTER TABLE dbo.TDSTCompanySetupSystemPOS ADD DefaultPaymentCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemPOS_Payment DEFAULT(N'CASH');

 IF OBJECT_ID(N'dbo.TDPOOutlet',N'U') IS NULL CREATE TABLE dbo.TDPOOutlet(
  OutletID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOOutlet PRIMARY KEY,CompanyID bigint NOT NULL,ProjectID bigint NOT NULL,
  OutletCode nvarchar(30) NOT NULL,OutletName nvarchar(150) NOT NULL,BranchID bigint NOT NULL,WarehouseID bigint NOT NULL,PriceLevelCode nvarchar(30) NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDPOOutlet_Active DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOOutlet_Create DEFAULT SYSUTCDATETIME(),UpdateBy bigint NULL,UpdateDate datetime2(3) NULL,
  CONSTRAINT UQ_TDPOOutlet_Company_Code UNIQUE(CompanyID,OutletCode)
 );
 IF OBJECT_ID(N'dbo.TDPOTerminal',N'U') IS NULL CREATE TABLE dbo.TDPOTerminal(
  TerminalID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOTerminal PRIMARY KEY,CompanyID bigint NOT NULL,OutletID bigint NOT NULL,
  TerminalCode nvarchar(30) NOT NULL,TerminalName nvarchar(150) NOT NULL,ActivationID uniqueidentifier NOT NULL CONSTRAINT DF_TDPOTerminal_Activation DEFAULT NEWID(),
  IsActive bit NOT NULL CONSTRAINT DF_TDPOTerminal_Active DEFAULT(1),LastSeenAt datetime2(3) NULL,CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOTerminal_Create DEFAULT SYSUTCDATETIME(),UpdateBy bigint NULL,UpdateDate datetime2(3) NULL,
  CONSTRAINT UQ_TDPOTerminal_Company_Code UNIQUE(CompanyID,TerminalCode),CONSTRAINT UQ_TDPOTerminal_Activation UNIQUE(ActivationID),
  CONSTRAINT FK_TDPOTerminal_Outlet FOREIGN KEY(OutletID) REFERENCES dbo.TDPOOutlet(OutletID)
 );
 IF OBJECT_ID(N'dbo.TDPOOutletItem',N'U') IS NULL CREATE TABLE dbo.TDPOOutletItem(
  OutletItemID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOOutletItem PRIMARY KEY,CompanyID bigint NOT NULL,OutletID bigint NOT NULL,ItemID bigint NOT NULL,
  Barcode nvarchar(100) NULL,SalePriceOverride decimal(18,4) NULL,IsSellable bit NOT NULL CONSTRAINT DF_TDPOOutletItem_Sellable DEFAULT(1),ShowStock bit NOT NULL CONSTRAINT DF_TDPOOutletItem_ShowStock DEFAULT(1),
  CreateBy bigint NULL,CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDPOOutletItem_Create DEFAULT SYSUTCDATETIME(),UpdateBy bigint NULL,UpdateDate datetime2(3) NULL,
  CONSTRAINT UQ_TDPOOutletItem UNIQUE(CompanyID,OutletID,ItemID),CONSTRAINT FK_TDPOOutletItem_Outlet FOREIGN KEY(OutletID) REFERENCES dbo.TDPOOutlet(OutletID)
 );
 IF OBJECT_ID(N'dbo.TDPOShift',N'U') IS NULL CREATE TABLE dbo.TDPOShift(
  ShiftID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPOShift PRIMARY KEY,CompanyID bigint NOT NULL,TerminalID bigint NOT NULL,ShiftCode nvarchar(40) NOT NULL,
  OpenedBy bigint NOT NULL,OpenedAt datetime2(3) NOT NULL CONSTRAINT DF_TDPOShift_Opened DEFAULT SYSUTCDATETIME(),OpeningCash decimal(18,4) NOT NULL,
  ClosedBy bigint NULL,ClosedAt datetime2(3) NULL,CountedCash decimal(18,4) NULL,ExpectedCash decimal(18,4) NULL,VarianceAmount decimal(18,4) NULL,
  StatusCode nvarchar(10) NOT NULL CONSTRAINT DF_TDPOShift_Status DEFAULT(N'OPEN'),Remark nvarchar(1000) NULL,
  CONSTRAINT UQ_TDPOShift_Company_Code UNIQUE(CompanyID,ShiftCode),CONSTRAINT FK_TDPOShift_Terminal FOREIGN KEY(TerminalID) REFERENCES dbo.TDPOTerminal(TerminalID),
  CONSTRAINT CK_TDPOShift_Status CHECK(StatusCode IN(N'OPEN',N'CLOSED'))
 );
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'UX_TDPOShift_OpenTerminal' AND object_id=OBJECT_ID(N'dbo.TDPOShift')) CREATE UNIQUE INDEX UX_TDPOShift_OpenTerminal ON dbo.TDPOShift(TerminalID) WHERE StatusCode=N'OPEN';
 UPDATE dbo.TDADProjectMenu SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode IN(N'46001',N'46002',N'46003',N'46004',N'46005',N'46006',N'46007');
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
