SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF COL_LENGTH(N'dbo.TDKNArticle',N'PublishedRevisionID') IS NULL
  EXEC(N'ALTER TABLE dbo.TDKNArticle ADD PublishedRevisionID bigint NULL');

 EXEC(N'UPDATE a SET PublishedRevisionID=a.CurrentRevisionID
  FROM dbo.TDKNArticle a
  WHERE a.PublishedRevisionID IS NULL
   AND a.StatusCode IN(N''PUBLISHED'',N''REVIEW_DUE'')
   AND a.CurrentRevisionID IS NOT NULL');

 IF NOT EXISTS(
  SELECT 1 FROM sys.foreign_keys
  WHERE parent_object_id=OBJECT_ID(N'dbo.TDKNArticle')
   AND name=N'FK_TDKNArticle_PublishedRevision')
  EXEC(N'ALTER TABLE dbo.TDKNArticle WITH CHECK
   ADD CONSTRAINT FK_TDKNArticle_PublishedRevision
   FOREIGN KEY(PublishedRevisionID) REFERENCES dbo.TDKNArticleRevision(RevisionID)');

 IF NOT EXISTS(
  SELECT 1 FROM sys.indexes
  WHERE object_id=OBJECT_ID(N'dbo.TDKNArticle')
   AND name=N'IX_TDKNArticle_PublishedRevision')
  EXEC(N'CREATE INDEX IX_TDKNArticle_PublishedRevision
   ON dbo.TDKNArticle(CompanyID,PublishedRevisionID)
   WHERE PublishedRevisionID IS NOT NULL');
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
