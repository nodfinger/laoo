SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_APPROVAL')
    THROW 54110, N'Approval project not found.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADFeature WHERE FeatureCode=N'APPROVAL_SYSTEM')
    THROW 54111, N'Approval feature not found.', 1;

UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบการอนุมัติ' WHERE ProjectCode=N'LAOO_APPROVAL';
UPDATE dbo.TDADFeature SET FeatureName=N'ระบบการอนุมัติ' WHERE FeatureCode=N'APPROVAL_SYSTEM';
