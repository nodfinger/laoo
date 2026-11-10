SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Register only; per-company capability remains disabled until an administrator enables it.
IF OBJECT_ID(N'dbo.TDADAiCapability', N'U') IS NULL
    THROW 53901, N'AI capability registry is missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADAiCapability WHERE CapabilityCode=N'repair.pending')
    INSERT dbo.TDADAiCapability(CapabilityCode, NameTH, DescriptionTH, ProjectCode)
    VALUES (N'repair.pending', N'ดูงานซ่อมรอรับ', N'แสดงงานซ่อมที่รอรับตามสิทธิ์ของผู้ใช้งาน', N'LAOO_SERVICE');
