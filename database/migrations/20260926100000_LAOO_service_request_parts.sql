/* Service repair parts: idempotent, additive only. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.TDADServiceRequestPart', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADServiceRequestPart
    (
        ServiceRequestPartID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADServiceRequestPart PRIMARY KEY,
        CompanyID bigint NOT NULL,
        RequestID bigint NOT NULL,
        StockIssueID bigint NULL,
        StockIssueDetailID bigint NULL,
        WarehouseID bigint NOT NULL,
        ItemID bigint NOT NULL,
        ItemCodeSnapshot nvarchar(50) NOT NULL,
        ItemNameSnapshot nvarchar(255) NOT NULL,
        UnitCodeSnapshot nvarchar(50) NULL,
        Quantity decimal(18,4) NOT NULL,
        UnitCostSnapshot decimal(18,4) NOT NULL,
        TotalCost AS (CONVERT(decimal(18,4), Quantity * UnitCostSnapshot)) PERSISTED,
        IsActive bit NOT NULL CONSTRAINT DF_TDADServiceRequestPart_IsActive DEFAULT (1),
        CreateDate datetime2 NOT NULL CONSTRAINT DF_TDADServiceRequestPart_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2 NULL,
        UpdateBy bigint NULL,
        CONSTRAINT CK_TDADServiceRequestPart_Quantity CHECK (Quantity > 0),
        CONSTRAINT FK_TDADServiceRequestPart_Request FOREIGN KEY (RequestID) REFERENCES dbo.TDADServiceRequest(RequestID),
        CONSTRAINT FK_TDADServiceRequestPart_Item FOREIGN KEY (ItemID) REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT FK_TDADServiceRequestPart_Warehouse FOREIGN KEY (WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID)
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceRequestPart') AND name=N'IX_TDADServiceRequestPart_CompanyRequest')
    CREATE INDEX IX_TDADServiceRequestPart_CompanyRequest ON dbo.TDADServiceRequestPart(CompanyID, RequestID, IsActive);

COMMIT TRANSACTION;
