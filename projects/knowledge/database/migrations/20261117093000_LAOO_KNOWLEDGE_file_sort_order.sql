IF COL_LENGTH(N'dbo.TDKNFile', N'SortOrder') IS NULL
    ALTER TABLE dbo.TDKNFile ADD SortOrder int NULL;
