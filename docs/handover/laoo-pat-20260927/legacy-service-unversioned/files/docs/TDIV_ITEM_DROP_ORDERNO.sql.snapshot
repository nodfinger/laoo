/* Remove the obsolete OrderNo field after application/API deployment. */
IF COL_LENGTH(N'dbo.TDIVItem', N'OrderNo') IS NOT NULL
BEGIN
    ALTER TABLE dbo.TDIVItem DROP COLUMN OrderNo;
END;
