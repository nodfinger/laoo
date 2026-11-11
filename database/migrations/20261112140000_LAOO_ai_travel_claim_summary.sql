SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADAiCapability',N'U') IS NULL OR OBJECT_ID(N'dbo.TDADAiCapabilityCompany',N'U') IS NULL
    THROW 54101,N'AI capability registry is missing.',1;
IF NOT EXISTS (
    SELECT 1
    FROM dbo.TDADProject P
    JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID AND PM.IsActive=1
    JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1 AND M.IsVisible=1
    WHERE P.ProjectCode=N'LAOO_MY' AND M.MenuCode=N'66001' AND M.ScreenType=4
)
    THROW 54102,N'Travel claim list menu 66001 is not available as ScreenType 4.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapability WHERE CapabilityCode=N'travel.claim_summary')
    INSERT dbo.TDADAiCapability(CapabilityCode,NameTH,DescriptionTH,ProjectCode)
    VALUES(N'travel.claim_summary',N'สรุปค่าเบิกเดินทาง',N'สรุปยอดและแยกประเภทค่าเบิกเดินทางตามช่วงเวลาและขอบเขตข้อมูลที่ผู้ใช้ได้รับอนุญาต',N'LAOO_MY');

INSERT dbo.TDADAiCapabilityCompany(CompanyID,CapabilityCode,IsEnabled,ExamplesJson)
SELECT C.CompanyID,N'travel.claim_summary',0,
       N'["เบิกค่าเดินทางทั้งหมดของฉันเดือนนี้เท่าไหร่","สรุปยอดเบิกค่าเดินทางของฉัน","รวมเบิกค่าเดินทางเดือนก่อนเท่าไหร่","แยกยอดเบิกค่าเดินทางตามประเภท","เดือนนี้ฉันเบิกค่าน้ำมันไปเท่าไหร่","ปีนี้ค่าห้องพักจากการเดินทางเท่าไหร่","สรุปค่าเบิกเดินทางของแผนก","รวมเบิกค่าเดินทางระดับฝ่าย"]'
FROM dbo.TDSTCompanySetUp C
WHERE C.OwnerType=N'C' AND C.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapabilityCompany X WHERE X.CompanyID=C.CompanyID AND X.CapabilityCode=N'travel.claim_summary');
