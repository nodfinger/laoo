SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.TDDCRevision',N'U') IS NULL
        THROW 51000, N'Document Control revision table is required.', 1;
    IF COL_LENGTH(N'dbo.TDDCRevision',N'ChangeReason') IS NULL
        ALTER TABLE dbo.TDDCRevision ADD ChangeReason nvarchar(2000) NULL;
    IF COL_LENGTH(N'dbo.TDDCRevision',N'ImpactAssessment') IS NULL
        ALTER TABLE dbo.TDDCRevision ADD ImpactAssessment nvarchar(2000) NULL;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
