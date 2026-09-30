SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.TDGPSetting',N'U') IS NULL
CREATE TABLE dbo.TDGPSetting(
 CompanyID bigint NOT NULL CONSTRAINT PK_TDGPSetting PRIMARY KEY,
 IsEnabled bit NOT NULL CONSTRAINT DF_TDGPSetting_Enabled DEFAULT(1),
 DefaultReturnDays int NOT NULL CONSTRAINT DF_TDGPSetting_ReturnDays DEFAULT(7),
 DefaultApproverUserID bigint NULL, UpdateDate datetime2(3) NOT NULL CONSTRAINT DF_TDGPSetting_Update DEFAULT SYSUTCDATETIME(), UpdateBy bigint NULL,
 CONSTRAINT CK_TDGPSetting_ReturnDays CHECK(DefaultReturnDays BETWEEN 1 AND 365));
IF OBJECT_ID(N'dbo.TDGPPurpose',N'U') IS NULL
CREATE TABLE dbo.TDGPPurpose(
 PurposeID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDGPPurpose PRIMARY KEY, CompanyID bigint NOT NULL,
 PurposeCode nvarchar(30) NOT NULL, PurposeName nvarchar(200) NOT NULL, IsActive bit NOT NULL CONSTRAINT DF_TDGPPurpose_Active DEFAULT(1),
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDGPPurpose_Create DEFAULT SYSUTCDATETIME(), CreateBy bigint NULL, UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
 CONSTRAINT UX_TDGPPurpose_Company_Code UNIQUE(CompanyID,PurposeCode));
IF OBJECT_ID(N'dbo.TDGPGatePass',N'U') IS NULL
CREATE TABLE dbo.TDGPGatePass(
 GatePassID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDGPGatePass PRIMARY KEY, CompanyID bigint NOT NULL, GatePassNo nvarchar(40) NOT NULL,
 PurposeID bigint NULL, RequesterUserID bigint NOT NULL, CarrierName nvarchar(200) NOT NULL, DestinationName nvarchar(300) NOT NULL, ExpectedReturnDate datetime2(3) NULL,
 IsReturnRequired bit NOT NULL CONSTRAINT DF_TDGPGatePass_Return DEFAULT(0), Remark nvarchar(1000) NULL, StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDGPGatePass_Status DEFAULT(N'DRAFT'),
 ApprovedAt datetime2(3) NULL, ApprovedBy bigint NULL, ApprovalRemark nvarchar(1000) NULL, HandedOverAt datetime2(3) NULL, HandedOverBy bigint NULL, HandoverRecipient nvarchar(200) NULL,
 ExitCheckedAt datetime2(3) NULL, ExitCheckedBy bigint NULL, ExitCheckRemark nvarchar(1000) NULL, ReturnedAt datetime2(3) NULL, ReturnedBy bigint NULL, ReturnRemark nvarchar(1000) NULL,
 CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDGPGatePass_Create DEFAULT SYSUTCDATETIME(), CreateBy bigint NULL, UpdateDate datetime2(3) NULL, UpdateBy bigint NULL,
 CONSTRAINT UX_TDGPGatePass_Company_No UNIQUE(CompanyID,GatePassNo), CONSTRAINT CK_TDGPGatePass_Status CHECK(StatusCode IN(N'DRAFT',N'PENDING_APPROVAL',N'APPROVED',N'HANDED_OVER',N'RETURNED',N'REJECTED',N'CANCELLED')),
 CONSTRAINT FK_TDGPGatePass_Purpose FOREIGN KEY(PurposeID) REFERENCES dbo.TDGPPurpose(PurposeID));
CREATE INDEX IX_TDGPGatePass_Company_Status ON dbo.TDGPGatePass(CompanyID,StatusCode,CreateDate DESC);
IF OBJECT_ID(N'dbo.TDGPGatePassItem',N'U') IS NULL
CREATE TABLE dbo.TDGPGatePassItem(
 GatePassItemID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDGPGatePassItem PRIMARY KEY, GatePassID bigint NOT NULL, CompanyID bigint NOT NULL, ItemID bigint NULL,
 ItemName nvarchar(300) NOT NULL, Quantity decimal(18,3) NOT NULL, UnitName nvarchar(80) NULL, SerialNo nvarchar(150) NULL,
 CONSTRAINT CK_TDGPGatePassItem_Quantity CHECK(Quantity>0), CONSTRAINT FK_TDGPGatePassItem_Header FOREIGN KEY(GatePassID) REFERENCES dbo.TDGPGatePass(GatePassID) ON DELETE CASCADE);
CREATE INDEX IX_TDGPGatePassItem_Header ON dbo.TDGPGatePassItem(GatePassID);
IF OBJECT_ID(N'dbo.TDGPApprovalHistory',N'U') IS NULL
CREATE TABLE dbo.TDGPApprovalHistory(
 GatePassApprovalHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDGPApprovalHistory PRIMARY KEY, CompanyID bigint NOT NULL, GatePassID bigint NOT NULL,
 ActionCode nvarchar(30) NOT NULL, Remark nvarchar(1000) NULL, ActionBy bigint NOT NULL, ActionDate datetime2(3) NOT NULL CONSTRAINT DF_TDGPApprovalHistory_Date DEFAULT SYSUTCDATETIME(),
 CONSTRAINT FK_TDGPApprovalHistory_Header FOREIGN KEY(GatePassID) REFERENCES dbo.TDGPGatePass(GatePassID) ON DELETE CASCADE);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_GATE_PASS' AND IsActive=1);
IF @project IS NULL THROW 52980,N'LAOO_GATE_PASS project is required.',1;
UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@project AND MenuGroupCode=N'38';
UPDATE dbo.TDADProjectMenu SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@project AND MenuCode BETWEEN N'38001' AND N'38008';
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
