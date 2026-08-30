/* Upgrade existing dbo.TDARCustomer for the Customer CRUD API.
   Safe to run more than once. Existing rows are assigned to CompanyID 1. */
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.TDARCustomer', N'U') IS NULL
    THROW 50001, 'ไม่พบตาราง dbo.TDARCustomer กรุณาสร้างตารางหลักก่อน', 1;

IF COL_LENGTH(N'dbo.TDARCustomer', N'CustomerID') IS NULL
BEGIN
    ALTER TABLE dbo.TDARCustomer
        ADD CustomerID BIGINT IDENTITY(1,1) NOT NULL;
END;
GO

IF COL_LENGTH(N'dbo.TDARCustomer', N'CompanyID') IS NULL
BEGIN
    ALTER TABLE dbo.TDARCustomer
        ADD CompanyID BIGINT NULL;
END;
GO

IF COL_LENGTH(N'dbo.TDARCustomer', N'IsActive') IS NULL
BEGIN
    ALTER TABLE dbo.TDARCustomer
        ADD IsActive BIT NOT NULL
            CONSTRAINT DF_TDARCustomer_IsActive_Migration DEFAULT (1);
END;
GO

UPDATE dbo.TDARCustomer
SET CompanyID = 1
WHERE CompanyID IS NULL;

IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.TDARCustomer')
      AND name = N'DF_TDARCustomer_CompanyID_Migration'
)
BEGIN
    ALTER TABLE dbo.TDARCustomer
        ADD CONSTRAINT DF_TDARCustomer_CompanyID_Migration DEFAULT (1) FOR CompanyID;
END;

ALTER TABLE dbo.TDARCustomer
    ALTER COLUMN CompanyID BIGINT NOT NULL;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDARCustomer')
      AND name = N'IX_TDARCustomer_Company_CustomerID'
)
BEGIN
    CREATE INDEX IX_TDARCustomer_Company_CustomerID
        ON dbo.TDARCustomer(CompanyID, CustomerID);
END;
GO
