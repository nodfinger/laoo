IF COL_LENGTH(N'dbo.TDKNContentReviewPolicy', N'ReviewerScope') IS NULL
    ALTER TABLE dbo.TDKNContentReviewPolicy ADD ReviewerScope nvarchar(20) NOT NULL
        CONSTRAINT DF_TDKNContentReviewPolicy_Scope DEFAULT(N'ANY');
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_TDKNContentReviewPolicy_Scope' AND parent_object_id=OBJECT_ID(N'dbo.TDKNContentReviewPolicy'))
    EXEC(N'ALTER TABLE dbo.TDKNContentReviewPolicy ADD CONSTRAINT CK_TDKNContentReviewPolicy_Scope
        CHECK (ReviewerScope IN(N''ANY'',N''DEPARTMENT'',N''DIVISION''));');
