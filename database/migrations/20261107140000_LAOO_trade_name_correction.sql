/* Correct the sales project and menu group labels without changing subscriptions. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF (SELECT COUNT(*) FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TRADE')<>1
    THROW 53400, N'Expected exactly one sales project.', 1;
IF (SELECT COUNT(*) FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'09')<>1
    THROW 53401, N'Expected exactly one sales menu group.', 1;

UPDATE dbo.TDADProject
SET ProjectNameTH=N'ระบบขาย', DescriptionText=N'ระบบขาย', UpdateDate=SYSUTCDATETIME()
WHERE ProjectCode=N'LAOO_TRADE';

UPDATE dbo.TDADMenuGroup
SET MenuGroupName=N'ระบบขาย', UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode=N'09';
