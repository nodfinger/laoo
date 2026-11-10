SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADAiCapability',N'U') IS NULL OR OBJECT_ID(N'dbo.TDADAiCapabilityCompany',N'U') IS NULL
    THROW 53901,N'AI capability registry is missing.',1;
DECLARE @items TABLE(Code nvarchar(100), NameTH nvarchar(200), DescriptionTH nvarchar(1000), Examples nvarchar(max));
INSERT @items VALUES
(N'meeting.availability',N'ค้นหาห้องประชุมว่าง',N'ค้นหาห้องประชุมที่ว่างตามวันและเวลาที่ระบุ',N'["พรุ่งนี้มีห้องว่างไหม","หาห้องประชุมว่าง","ตรวจสอบห้องว่าง","ห้องประชุมไหนว่างบ้าง","ค้นหาห้องประชุม"]'),
(N'meeting.own_bookings',N'การจองห้องประชุมของฉัน',N'ดูรายการจองและสถานะเฉพาะที่ผู้ใช้สร้าง',N'["การจองห้องประชุมของฉันอยู่สถานะอะไร","ดูรายการจองห้องของฉัน","ห้องที่ฉันจองไว้","ตรวจสอบการจองของฉัน","สถานะจองห้องประชุม"]'),
(N'meeting.invitations',N'คำเชิญประชุมของฉัน',N'ดูคำเชิญประชุมของผู้ใช้งาน',N'["ฉันมีประชุมอะไรวันนี้","ดูคำเชิญประชุมของฉัน","ฉันมีประชุมอะไรบ้าง","รายการประชุมที่ฉันได้รับเชิญ","ตรวจสอบคำเชิญประชุม"]');
INSERT dbo.TDADAiCapability(CapabilityCode,NameTH,DescriptionTH,ProjectCode)
SELECT Code,NameTH,DescriptionTH,N'LAOO_MEETING' FROM @items I
WHERE NOT EXISTS (SELECT 1 FROM dbo.TDADAiCapability C WHERE C.CapabilityCode=I.Code);
INSERT dbo.TDADAiCapabilityCompany(CompanyID,CapabilityCode,IsEnabled,ExamplesJson)
SELECT C.CompanyID,I.Code,0,I.Examples FROM dbo.TDSTCompanySetUp C CROSS JOIN @items I
WHERE C.OwnerType=N'C' AND C.IsActive=1 AND NOT EXISTS
(SELECT 1 FROM dbo.TDADAiCapabilityCompany CC WHERE CC.CompanyID=C.CompanyID AND CC.CapabilityCode=I.Code);
