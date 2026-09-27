SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @ProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO' AND IsActive=1
    ORDER BY ProjectID
);

IF @ProjectID IS NULL
    THROW 50001, 'LAOO_PROJECT_NOT_FOUND', 1;

DECLARE @Features TABLE
(
    FeatureCode nvarchar(50) NOT NULL PRIMARY KEY,
    FeatureName nvarchar(200) NOT NULL,
    FeatureDescription nvarchar(500) NULL,
    SortOrder int NOT NULL
);

INSERT INTO @Features (FeatureCode, FeatureName, FeatureDescription, SortOrder)
VALUES
    (N'SALES', N'ระบบบริหารงานขาย', N'ลูกค้า สินค้า เอกสารขาย การส่งมอบ และเอกสารรับเงิน', 10),
    (N'SERVICE', N'ระบบงานซ่อม', N'รับแจ้งซ่อม บำรุงรักษา ใบงานช่าง และรายงานบริการ', 20),
    (N'ATTENDANCE', N'ระบบบันทึกเวลาทำงาน', N'ลงเวลา กะการทำงาน การอนุมัติ และรายงานเวลา', 30),
    (N'VISITOR', N'ระบบผู้มาติดต่อ', N'ลงทะเบียนผู้มาติดต่อ นัดหมาย เข้า-ออก และประวัติการเข้าใช้พื้นที่', 40);

UPDATE F
SET F.FeatureName=S.FeatureName,
    F.FeatureDescription=S.FeatureDescription,
    F.SortOrder=S.SortOrder,
    F.IsActive=1,
    F.UpdateDate=SYSUTCDATETIME()
FROM dbo.TDADFeature F
INNER JOIN @Features S ON S.FeatureCode=F.FeatureCode;

INSERT INTO dbo.TDADFeature
    (FeatureCode, FeatureName, FeatureDescription, IsActive, SortOrder, CreateDate, CreatedBy)
SELECT S.FeatureCode, S.FeatureName, S.FeatureDescription, 1, S.SortOrder, SYSUTCDATETIME(), NULL
FROM @Features S
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADFeature F WHERE F.FeatureCode=S.FeatureCode
);

UPDATE dbo.TDADMenuGroup
SET OpenOption=1
WHERE MenuGroupCode IN (N'09', N'14', N'15', N'16', N'17', N'19', N'20');

UPDATE dbo.TDADMainMenu
SET FeatureCode=N'SALES'
WHERE MenuGroupCode=N'09' AND IsActive=1;

UPDATE dbo.TDADMainMenu
SET FeatureCode=N'SERVICE'
WHERE MenuGroupCode IN (N'14', N'15', N'16', N'17', N'19', N'20') AND IsActive=1;

INSERT INTO dbo.TDADCompanyFeature
    (ProjectID, PartnerID, CompanyID, FeatureCode, IsEnabled, IsTrial,
     StartDate, ExpireDate, CreateDate, CreatedBy)
SELECT @ProjectID, C.PartnerID, C.CompanyID, F.FeatureCode, 1, 0,
       NULL, NULL, SYSUTCDATETIME(), NULL
FROM dbo.TDSTCompanySetUp C
CROSS JOIN @Features F
WHERE C.CompanyID IS NOT NULL
  AND C.PartnerID IS NOT NULL
  AND C.IsActive=1
  AND F.FeatureCode IN (N'SALES', N'SERVICE')
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.TDADCompanyFeature CF
      WHERE CF.ProjectID=@ProjectID
        AND CF.PartnerID=C.PartnerID
        AND CF.CompanyID=C.CompanyID
        AND CF.FeatureCode=F.FeatureCode
  );

COMMIT TRANSACTION;

SELECT FeatureCode, FeatureName, IsActive, SortOrder
FROM dbo.TDADFeature
WHERE FeatureCode IN (N'SALES', N'SERVICE', N'ATTENDANCE', N'VISITOR')
ORDER BY SortOrder;

SELECT FeatureCode, COUNT(*) AS CompanyCount,
       SUM(CASE WHEN IsEnabled=1 THEN 1 ELSE 0 END) AS EnabledCount
FROM dbo.TDADCompanyFeature
WHERE ProjectID=@ProjectID
  AND FeatureCode IN (N'SALES', N'SERVICE', N'ATTENDANCE', N'VISITOR')
GROUP BY FeatureCode
ORDER BY FeatureCode;
