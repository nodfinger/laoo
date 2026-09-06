/* Remove the obsolete detail field after application/API deployment. */
IF COL_LENGTH(N'dbo.TDIVItem', N'RemarkItem2') IS NOT NULL
BEGIN
    ALTER TABLE dbo.TDIVItem DROP COLUMN RemarkItem2;
END;
