IF COL_LENGTH(N'dbo.TDKNArticle', N'ResponsibleDepartmentID') IS NULL
    ALTER TABLE dbo.TDKNArticle ADD ResponsibleDepartmentID bigint NULL;
