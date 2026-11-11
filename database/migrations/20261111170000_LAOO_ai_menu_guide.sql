IF NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapability WHERE CapabilityCode=N'core.menu_guide')
 INSERT dbo.TDADAiCapability(CapabilityCode,NameTH,DescriptionTH,ProjectCode,IsActive)
 VALUES(N'core.menu_guide',N'แนะนำเมนูคีย์ข้อมูล',N'แนะนำเมนูและลิงก์ตามสิทธิ์ของผู้ใช้',N'LAOO_AI',1);
INSERT dbo.TDADAiCapabilityCompany(CompanyID,CapabilityCode,IsEnabled,ExamplesJson)
SELECT DISTINCT CompanyID,N'core.menu_guide',0,N'["จะคีย์สินค้าไปเมนูไหน","เพิ่มพนักงานที่เมนูอะไร","เบิกค่าเดินทางเข้าเมนูไหน"]'
FROM dbo.TDSTCompanySetUp S WHERE S.OwnerType=N'C' AND S.CompanyID IS NOT NULL
AND NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapabilityCompany C WHERE C.CompanyID=S.CompanyID AND C.CapabilityCode=N'core.menu_guide');
