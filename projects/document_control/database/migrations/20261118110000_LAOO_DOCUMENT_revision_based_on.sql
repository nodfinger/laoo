SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.TDDCRevision',N'U') IS NULL
        THROW 51000, N'Document Control revision table is required.', 1;
    IF COL_LENGTH(N'dbo.TDDCRevision',N'BasedOnRevisionID') IS NULL
        ALTER TABLE dbo.TDDCRevision ADD BasedOnRevisionID bigint NULL;
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.TDDCRevision') AND name=N'FK_TDDCRevision_BasedOn')
        ALTER TABLE dbo.TDDCRevision WITH CHECK ADD CONSTRAINT FK_TDDCRevision_BasedOn FOREIGN KEY (BasedOnRevisionID) REFERENCES dbo.TDDCRevision(RevisionID);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
