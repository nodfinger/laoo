SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTMenuDataAccessAudit', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSTMenuDataAccessAudit (
  CompanyID bigint NOT NULL,
  MenuCode nvarchar(20) NOT NULL,
  UpdateBy bigint NOT NULL,
  UpdateDate datetime2 NOT NULL,
  CONSTRAINT PK_MenuDataAccessAudit PRIMARY KEY (CompanyID, MenuCode)
 );
END;
INSERT dbo.TDSTMenuDataAccessAudit(CompanyID,MenuCode,UpdateBy,UpdateDate)
SELECT p.CompanyID,p.MenuCode,p.UpdateBy,p.UpdateDate
FROM dbo.TDSTMenuDataAccessPolicy p
WHERE NOT EXISTS (SELECT 1 FROM dbo.TDSTMenuDataAccessAudit a WHERE a.CompanyID=p.CompanyID AND a.MenuCode=p.MenuCode);
