SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADAiCapability',N'U') IS NULL THROW 53901,N'AI capability registry is missing.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapability WHERE CapabilityCode=N'repair.serial_history')
    INSERT dbo.TDADAiCapability(CapabilityCode,NameTH,DescriptionTH,ProjectCode)
    VALUES(N'repair.serial_history',N'ประวัติซ่อมตาม Serial',N'แสดงงานซ่อมที่เสร็จของอุปกรณ์ตามสิทธิ์',N'LAOO_SERVICE');
