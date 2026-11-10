SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADAiCapability', N'U') IS NULL
    THROW 53901, N'AI capability registry is missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADAiCapability WHERE CapabilityCode=N'stock.serial_lookup')
    INSERT dbo.TDADAiCapability(CapabilityCode,NameTH,DescriptionTH,ProjectCode)
    VALUES (N'stock.serial_lookup',N'ค้นหา Serial และตรวจประกัน',N'ค้นหาอุปกรณ์และประกันตาม Serial โดยตรวจสิทธิ์ทะเบียนและคลัง',N'LAOO_STOCK');
-- Company settings are intentionally not created or enabled by this migration.
