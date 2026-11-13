SET NOCOUNT ON;

UPDATE dbo.TDADProject
SET ProjectNameTH = N'ระบบจัดซื้อ'
WHERE ProjectCode = N'LAOO_PURCHASING';

UPDATE dbo.TDADFeature
SET FeatureName = N'ระบบจัดซื้อ'
WHERE FeatureCode = N'PURCHASING';

UPDATE permission
SET ActionNameTH = labels.ActionNameTH
FROM dbo.TDADPermission permission
JOIN (VALUES
    (N'VIEW', N'ดูข้อมูล'),
    (N'CREATE', N'เพิ่ม'),
    (N'EDIT', N'แก้ไข'),
    (N'DELETE', N'ลบ'),
    (N'UPLOAD', N'แนบไฟล์')
) labels(ActionCode, ActionNameTH) ON labels.ActionCode = permission.ActionCode
WHERE permission.ProjectID = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_PURCHASING')
  AND permission.ScreenCode = N'69002';

UPDATE dbo.TDADProjectPackage
SET PackageNameTH = N'มาตรฐาน'
WHERE ProjectID = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_PURCHASING')
  AND PackageCode = N'STANDARD';
