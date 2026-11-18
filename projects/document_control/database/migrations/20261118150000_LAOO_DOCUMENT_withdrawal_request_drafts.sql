SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.TDDCChangeRequest',N'U') IS NULL
        THROW 51000, N'Document Control change requests are required.', 1;
    IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDDCChangeRequest') AND name=N'UQ_TDDCChangeRequest_Revision')
        ALTER TABLE dbo.TDDCChangeRequest DROP CONSTRAINT UQ_TDDCChangeRequest_Revision;
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDDCChangeRequest') AND name=N'UX_TDDCChangeRequest_ActiveDraft')
        CREATE UNIQUE INDEX UX_TDDCChangeRequest_ActiveDraft ON dbo.TDDCChangeRequest(CompanyID,RevisionID,RequestType) WHERE StatusCode=N'DRAFT';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
