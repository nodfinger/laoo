-- Optional cleanup, NOT executed automatically.
-- Retire precisely identified demo records. Financial ledgers remain append-only.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@co);
IF @co IS NULL OR @actor IS NULL THROW 57311,N'Demo owner not found.',1;
UPDATE I SET IsActive=0 FROM dbo.TDSFStudentIdentifier I
JOIN dbo.TDSCStudent S ON S.CompanyID=I.CompanyID AND S.StudentID=I.StudentID
WHERE S.CompanyID=@co AND S.StudentCode IN(N'SFDEMO001',N'SFDEMO002') AND S.LastName=N'SF_20261004_DEMO';
UPDATE dbo.TDSFShop SET IsActive=0 WHERE CompanyID=@co AND ShopCode IN(N'SFDEMO-FOOD',N'SFDEMO-DRINK') AND ShopName LIKE N'%[[]SF_20261004_DEMO]';
UPDATE dbo.TDSCStudent SET IsActive=0 WHERE CompanyID=@co AND StudentCode IN(N'SFDEMO001',N'SFDEMO002') AND LastName=N'SF_20261004_DEMO';
UPDATE dbo.TDIVItem SET IsActive=0 WHERE CompanyID=@co AND ItemCode IN(N'SFDEMO-RICE',N'SFDEMO-WATER') AND RemarkItem1=N'SF_20261004_DEMO';
INSERT dbo.TDSFAudit(CompanyID,UserID,ActionCode,EntityType,EntityID,DetailJson)
VALUES(@co,@actor,N'DEMO_RETIRE',N'RUN',0,N'{"runId":"SF_20261004_DEMO","retained":"wallet ledger, sales, refunds, stock history"}');
COMMIT;
-- School/classroom, permissions, trial and historical stock are intentionally retained.
-- No deletion of ledger, no broad DELETE, no changes to real students/items.
