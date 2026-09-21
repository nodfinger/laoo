-- Core fix: activate the shared Visitor location menu group for Navigation.
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'33')
    THROW 53110, N'MenuGroup 33 is required for Visitor navigation.', 1;

UPDATE dbo.TDADMenuGroup
SET IsActive=1, UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode=N'33' AND IsActive=0;