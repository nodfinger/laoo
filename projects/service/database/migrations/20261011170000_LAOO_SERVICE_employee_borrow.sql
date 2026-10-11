SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @CoreProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @CoreProjectID IS NULL THROW 59200,N'LAOO core project is required',1;

DECLARE @Menus table(Code char(5),Name nvarchar(100),ScreenType int,RouteName nvarchar(100),RoutePath nvarchar(200),SortOrder int);
INSERT @Menus VALUES
(N'08008',N'คำขอยืม',4,N'employeeBorrowRequests',N'/inventory/borrow-requests',8),
(N'08009',N'งานอนุมัติ',3,N'employeeBorrowApprovals',N'/inventory/borrow-approvals',9),
(N'08010',N'ส่งมอบและรับคืน',4,N'employeeBorrowTransfers',N'/inventory/borrow-transfers',10),
(N'08011',N'ประวัติและรายงาน',3,N'employeeBorrowHistory',N'/inventory/borrow-history',11);
IF EXISTS(SELECT 1 FROM @Menus M JOIN dbo.TDADMainMenu X ON X.MenuCode=M.Code
          WHERE X.ScreenType<>M.ScreenType OR X.RouteName<>M.RouteName)
    THROW 59201,N'Borrow menu contract conflicts with existing metadata',1;
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
SELECT Code,N'08',Name,ScreenType,RouteName,RoutePath,NULL,N'swap_horiz_outlined',SortOrder,1,1,1 FROM @Menus M
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu X WHERE X.MenuCode=M.Code);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @CoreProjectID,Code,N'08',SortOrder,1,SYSUTCDATETIME() FROM @Menus M
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu X WHERE X.ProjectID=@CoreProjectID AND X.MenuCode=M.Code);

DECLARE @Actions table(Code char(5),ActionCode nvarchar(20),Name nvarchar(50));
INSERT @Actions
SELECT M.Code,A.ActionCode,A.Name FROM @Menus M CROSS APPLY (VALUES
 (N'VIEW',N'แสดง'),(N'CREATE',N'เพิ่ม'),(N'EDIT',N'แก้ไข'),(N'DELETE',N'ลบ'),
 (N'APPROVE',N'อนุมัติ'),(N'REJECT',N'ปฏิเสธ'),(N'ISSUE',N'ส่งมอบ'),(N'RETURN',N'รับคืน'),(N'EXPORT',N'ส่งออก')) A(ActionCode,Name)
WHERE A.ActionCode=N'VIEW'
 OR (M.Code=N'08008' AND A.ActionCode IN(N'CREATE',N'EDIT',N'DELETE'))
 OR (M.Code=N'08009' AND A.ActionCode IN(N'APPROVE',N'REJECT'))
 OR (M.Code=N'08010' AND A.ActionCode IN(N'ISSUE',N'RETURN'))
 OR (M.Code=N'08011' AND A.ActionCode=N'EXPORT');
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @CoreProjectID,A.Code,M.Name,M.RouteName,A.ActionCode,A.Name,A.ActionCode,1,SYSUTCDATETIME()
FROM @Actions A JOIN @Menus M ON M.Code=A.Code
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@CoreProjectID AND P.ScreenCode=A.Code AND P.ActionCode=A.ActionCode);

IF OBJECT_ID(N'dbo.TDIVBorrowApprovalRoute',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowApprovalRoute(
  BorrowApprovalRouteID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowApprovalRoute PRIMARY KEY,
  CompanyID bigint NOT NULL, RouteName nvarchar(200) NOT NULL, IsDefault bit NOT NULL CONSTRAINT DF_TDIVBorrowApprovalRoute_Default DEFAULT(0),
  IsActive bit NOT NULL CONSTRAINT DF_TDIVBorrowApprovalRoute_Active DEFAULT(1),
  CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVBorrowApprovalRoute_Create DEFAULT SYSUTCDATETIME(), CreatedBy bigint NULL,
  UpdateDate datetime2(3) NULL, UpdatedBy bigint NULL,
  CONSTRAINT UQ_TDIVBorrowApprovalRoute_Name UNIQUE(CompanyID,RouteName));
 CREATE UNIQUE INDEX UX_TDIVBorrowApprovalRoute_Default ON dbo.TDIVBorrowApprovalRoute(CompanyID) WHERE IsDefault=1 AND IsActive=1;
END;
IF OBJECT_ID(N'dbo.TDIVBorrowApprovalRouteStep',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowApprovalRouteStep(
  BorrowApprovalRouteStepID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowApprovalRouteStep PRIMARY KEY,
  CompanyID bigint NOT NULL, BorrowApprovalRouteID bigint NOT NULL, StepNo int NOT NULL, ApproverUserID bigint NOT NULL,
  CONSTRAINT FK_TDIVBorrowApprovalRouteStep_Route FOREIGN KEY(BorrowApprovalRouteID) REFERENCES dbo.TDIVBorrowApprovalRoute(BorrowApprovalRouteID),
  CONSTRAINT UQ_TDIVBorrowApprovalRouteStep_No UNIQUE(BorrowApprovalRouteID,StepNo),
  CONSTRAINT CK_TDIVBorrowApprovalRouteStep_No CHECK(StepNo>0));
END;
IF COL_LENGTH(N'dbo.TDIVItem',N'IsBorrowable') IS NULL ALTER TABLE dbo.TDIVItem ADD IsBorrowable bit NOT NULL CONSTRAINT DF_TDIVItem_IsBorrowable DEFAULT(0);
IF COL_LENGTH(N'dbo.TDIVItem',N'BorrowApprovalRequired') IS NULL ALTER TABLE dbo.TDIVItem ADD BorrowApprovalRequired bit NOT NULL CONSTRAINT DF_TDIVItem_BorrowApprovalRequired DEFAULT(0);
IF COL_LENGTH(N'dbo.TDIVItem',N'BorrowMaxDays') IS NULL ALTER TABLE dbo.TDIVItem ADD BorrowMaxDays int NULL;
IF COL_LENGTH(N'dbo.TDIVItem',N'BorrowApprovalRouteID') IS NULL ALTER TABLE dbo.TDIVItem ADD BorrowApprovalRouteID bigint NULL;
IF OBJECT_ID(N'dbo.CK_TDIVItem_BorrowPolicy',N'C') IS NULL
 EXEC(N'ALTER TABLE dbo.TDIVItem ADD CONSTRAINT CK_TDIVItem_BorrowPolicy CHECK(IsBorrowable=0 OR (ItemKindCode=N''GOODS'' AND StockTrackingCode IN(N''QUANTITY'',N''SERIAL'') AND BorrowMaxDays>0))');
IF OBJECT_ID(N'dbo.FK_TDIVItem_BorrowRoute',N'F') IS NULL
 ALTER TABLE dbo.TDIVItem ADD CONSTRAINT FK_TDIVItem_BorrowRoute FOREIGN KEY(BorrowApprovalRouteID) REFERENCES dbo.TDIVBorrowApprovalRoute(BorrowApprovalRouteID);

IF OBJECT_ID(N'dbo.TDIVBorrowRequest',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowRequest(
  BorrowRequestID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowRequest PRIMARY KEY,
  CompanyID bigint NOT NULL, WarehouseID bigint NOT NULL, EmployeeID bigint NOT NULL,
  RequestCode nvarchar(40) NOT NULL, RequestDate date NOT NULL, PlannedIssueDate date NOT NULL, DueDate date NOT NULL,
  BorrowApprovalRouteID bigint NULL, RouteNameSnapshot nvarchar(200) NULL,
  StatusCode nvarchar(25) NOT NULL, Remark nvarchar(1000) NULL, RunID nvarchar(80) NULL,
  CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVBorrowRequest_Create DEFAULT SYSUTCDATETIME(),CreatedBy bigint NOT NULL,
  UpdateDate datetime2(3) NULL,UpdatedBy bigint NULL,
  CONSTRAINT FK_TDIVBorrowRequest_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
  CONSTRAINT FK_TDIVBorrowRequest_Route FOREIGN KEY(BorrowApprovalRouteID) REFERENCES dbo.TDIVBorrowApprovalRoute(BorrowApprovalRouteID),
  CONSTRAINT UQ_TDIVBorrowRequest_Code UNIQUE(CompanyID,RequestCode),
  CONSTRAINT CK_TDIVBorrowRequest_Date CHECK(DueDate>=PlannedIssueDate),
  CONSTRAINT CK_TDIVBorrowRequest_Status CHECK(StatusCode IN(N'WAIT_APPROVAL',N'READY',N'REJECTED',N'CANCELLED',N'ISSUED',N'PARTIAL_RETURN',N'RETURNED')));
 CREATE INDEX IX_TDIVBorrowRequest_List ON dbo.TDIVBorrowRequest(CompanyID,StatusCode,RequestDate DESC);
END;
IF OBJECT_ID(N'dbo.TDIVBorrowRequestLine',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowRequestLine(
  BorrowRequestLineID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowRequestLine PRIMARY KEY,
  CompanyID bigint NOT NULL,BorrowRequestID bigint NOT NULL,[LineNo] int NOT NULL,ItemID bigint NOT NULL,
  Quantity decimal(18,4) NOT NULL,IssuedQuantity decimal(18,4) NOT NULL CONSTRAINT DF_TDIVBorrowLine_Issued DEFAULT(0),
  ReturnedQuantity decimal(18,4) NOT NULL CONSTRAINT DF_TDIVBorrowLine_Returned DEFAULT(0),
  StockTrackingSnapshot nvarchar(20) NOT NULL,ApprovalRequiredSnapshot bit NOT NULL,MaxDaysSnapshot int NOT NULL,
  CONSTRAINT FK_TDIVBorrowLine_Request FOREIGN KEY(BorrowRequestID) REFERENCES dbo.TDIVBorrowRequest(BorrowRequestID),
  CONSTRAINT FK_TDIVBorrowLine_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID),
  CONSTRAINT UQ_TDIVBorrowLine_No UNIQUE(BorrowRequestID,[LineNo]),
  CONSTRAINT CK_TDIVBorrowLine_Quantity CHECK(Quantity>0 AND IssuedQuantity>=0 AND ReturnedQuantity>=0 AND ReturnedQuantity<=IssuedQuantity AND IssuedQuantity<=Quantity));
 CREATE INDEX IX_TDIVBorrowLine_Reservations ON dbo.TDIVBorrowRequestLine(CompanyID,ItemID,BorrowRequestID);
END;
IF OBJECT_ID(N'dbo.TDIVBorrowSerial',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowSerial(
  BorrowSerialID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowSerial PRIMARY KEY,
  CompanyID bigint NOT NULL,BorrowRequestLineID bigint NOT NULL,ItemInstanceID bigint NOT NULL,
  StatusCode nvarchar(15) NOT NULL,
  CONSTRAINT FK_TDIVBorrowSerial_Line FOREIGN KEY(BorrowRequestLineID) REFERENCES dbo.TDIVBorrowRequestLine(BorrowRequestLineID),
  CONSTRAINT FK_TDIVBorrowSerial_Instance FOREIGN KEY(ItemInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID),
  CONSTRAINT UQ_TDIVBorrowSerial_Line_Instance UNIQUE(BorrowRequestLineID,ItemInstanceID),
  CONSTRAINT CK_TDIVBorrowSerial_Status CHECK(StatusCode IN(N'RESERVED',N'ISSUED',N'RETURNED',N'RELEASED')));
 CREATE INDEX IX_TDIVBorrowSerial_Instance_Status ON dbo.TDIVBorrowSerial(CompanyID,ItemInstanceID,StatusCode);
END;
IF OBJECT_ID(N'dbo.TDIVBorrowApproval',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowApproval(
  BorrowApprovalID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowApproval PRIMARY KEY,
  CompanyID bigint NOT NULL,BorrowRequestID bigint NOT NULL,StepNo int NOT NULL,ApproverUserID bigint NOT NULL,
  StatusCode nvarchar(15) NOT NULL CONSTRAINT DF_TDIVBorrowApproval_Status DEFAULT(N'PENDING'),
  DecisionDate datetime2(3) NULL,Reason nvarchar(1000) NULL,
  CONSTRAINT FK_TDIVBorrowApproval_Request FOREIGN KEY(BorrowRequestID) REFERENCES dbo.TDIVBorrowRequest(BorrowRequestID),
  CONSTRAINT UQ_TDIVBorrowApproval_Step UNIQUE(BorrowRequestID,StepNo),
  CONSTRAINT CK_TDIVBorrowApproval_Status CHECK(StatusCode IN(N'PENDING',N'APPROVED',N'REJECTED')));
END;
IF OBJECT_ID(N'dbo.TDIVBorrowTransfer',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowTransfer(
  BorrowTransferID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowTransfer PRIMARY KEY,
  CompanyID bigint NOT NULL,BorrowRequestLineID bigint NOT NULL,ItemInstanceID bigint NULL,
  TransferType nvarchar(10) NOT NULL,Quantity decimal(18,4) NOT NULL,
  ConditionNote nvarchar(1000) NULL,TransferDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVBorrowTransfer_Date DEFAULT SYSUTCDATETIME(),CreatedBy bigint NOT NULL,
  CONSTRAINT FK_TDIVBorrowTransfer_Line FOREIGN KEY(BorrowRequestLineID) REFERENCES dbo.TDIVBorrowRequestLine(BorrowRequestLineID),
  CONSTRAINT FK_TDIVBorrowTransfer_Instance FOREIGN KEY(ItemInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID),
  CONSTRAINT CK_TDIVBorrowTransfer_Type CHECK(TransferType IN(N'ISSUE',N'RETURN')),
  CONSTRAINT CK_TDIVBorrowTransfer_Quantity CHECK(Quantity>0));
END;
IF OBJECT_ID(N'dbo.TDIVBorrowPhoto',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowPhoto(
  BorrowPhotoID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowPhoto PRIMARY KEY,
  CompanyID bigint NOT NULL,BorrowTransferID bigint NOT NULL,
  FilePath nvarchar(500) NOT NULL,FileName nvarchar(255) NOT NULL,ContentType nvarchar(100) NOT NULL,
  FileSize bigint NOT NULL,Sha256 char(64) NOT NULL,
  CONSTRAINT FK_TDIVBorrowPhoto_Transfer FOREIGN KEY(BorrowTransferID) REFERENCES dbo.TDIVBorrowTransfer(BorrowTransferID),
  CONSTRAINT CK_TDIVBorrowPhoto_Size CHECK(FileSize>0));
END;
IF OBJECT_ID(N'dbo.TDIVBorrowAudit',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDIVBorrowAudit(
  BorrowAuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVBorrowAudit PRIMARY KEY,
  CompanyID bigint NOT NULL,BorrowRequestID bigint NOT NULL,ActionCode nvarchar(30) NOT NULL,
  Detail nvarchar(1000) NULL,ActionDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVBorrowAudit_Date DEFAULT SYSUTCDATETIME(),UserID bigint NOT NULL,
  CONSTRAINT FK_TDIVBorrowAudit_Request FOREIGN KEY(BorrowRequestID) REFERENCES dbo.TDIVBorrowRequest(BorrowRequestID));
END;
IF OBJECT_ID(N'dbo.CK_TDIVStockMovement_Type',N'C') IS NOT NULL
 ALTER TABLE dbo.TDIVStockMovement DROP CONSTRAINT CK_TDIVStockMovement_Type;
ALTER TABLE dbo.TDIVStockMovement ADD CONSTRAINT CK_TDIVStockMovement_Type CHECK(MovementType IN
 (N'OPENING',N'RECEIPT',N'ISSUE',N'SALE_OUT',N'TRANSFER_IN',N'TRANSFER_OUT',N'ADJUST',N'REVERSAL',N'BORROW_OUT',N'BORROW_RETURN'));
COMMIT TRANSACTION;
