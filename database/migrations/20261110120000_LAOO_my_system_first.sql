SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MY' AND IsActive=1);
IF @ProjectID IS NULL THROW 53910, N'Active My System project not found.', 1;
DECLARE @FirstOrder int = (SELECT MIN(SortOrder) FROM dbo.TDADProject WHERE IsActive=1 AND ProjectID<>@ProjectID);
IF @FirstOrder IS NULL SET @FirstOrder=1;
IF @FirstOrder<=-2147483648 THROW 53911, N'Cannot place My System first.', 1;
UPDATE dbo.TDADProject SET SortOrder=@FirstOrder-1 WHERE ProjectID=@ProjectID AND SortOrder>=@FirstOrder;
