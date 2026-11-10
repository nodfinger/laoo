SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Existing requests remain unassociated: an item type does not identify a particular unit.
IF OBJECT_ID(N'dbo.TDADServiceRequest', N'U') IS NULL OR OBJECT_ID(N'dbo.TDIVItemInstance', N'U') IS NULL
    THROW 53951, N'Service request or serial registry table is missing.', 1;

IF COL_LENGTH(N'dbo.TDADServiceRequest', N'EquipmentInstanceID') IS NULL
    ALTER TABLE dbo.TDADServiceRequest ADD EquipmentInstanceID bigint NULL;

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.TDADServiceRequest') AND name=N'FK_ServiceRequest_EquipmentInstance')
    EXEC(N'ALTER TABLE dbo.TDADServiceRequest WITH CHECK ADD CONSTRAINT FK_ServiceRequest_EquipmentInstance
        FOREIGN KEY (EquipmentInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID)');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceRequest') AND name=N'IX_ServiceRequest_Company_EquipmentInstance')
    EXEC(N'CREATE INDEX IX_ServiceRequest_Company_EquipmentInstance
        ON dbo.TDADServiceRequest(CompanyID, EquipmentInstanceID) WHERE EquipmentInstanceID IS NOT NULL');
