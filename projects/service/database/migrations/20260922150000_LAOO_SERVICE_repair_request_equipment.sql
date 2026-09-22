SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'EquipmentItemID') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD EquipmentItemID bigint NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'EquipmentCodeSnapshot') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD EquipmentCodeSnapshot nvarchar(50) NULL;
IF COL_LENGTH(N'dbo.TDADServiceRequest',N'EquipmentNameSnapshot') IS NULL ALTER TABLE dbo.TDADServiceRequest ADD EquipmentNameSnapshot nvarchar(200) NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceRequest') AND name=N'IX_TDADServiceRequest_Company_Equipment')
    CREATE INDEX IX_TDADServiceRequest_Company_Equipment ON dbo.TDADServiceRequest(CompanyID,EquipmentItemID);
COMMIT TRANSACTION;