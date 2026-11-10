SET XACT_ABORT ON;
SET NOCOUNT ON;
-- Only document screens whose creation paths use the configured allocator.
UPDATE dbo.TDADMainMenu SET RunData=1
WHERE MenuCode IN (N'08003',N'08005',N'09004',N'09005',N'09006',N'09007')
  AND ScreenType=4 AND IsActive=1 AND RunData=0;
