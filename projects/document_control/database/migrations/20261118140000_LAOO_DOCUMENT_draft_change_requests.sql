SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.TDDCDocument',N'U') IS NULL OR OBJECT_ID(N'dbo.TDDCRevision',N'U') IS NULL
        THROW 51000, N'Document Control tables are required.', 1;
    IF OBJECT_ID(N'dbo.TDDCChangeRequest',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDDCChangeRequest (
            ChangeRequestID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
            CompanyID bigint NOT NULL,
            DocumentID bigint NOT NULL,
            RevisionID bigint NOT NULL,
            RequestType nvarchar(20) NOT NULL,
            StatusCode nvarchar(20) NOT NULL,
            RequesterUserID bigint NOT NULL,
            Reason nvarchar(2000) NULL,
            ImpactAssessment nvarchar(2000) NULL,
            CreateDate datetime2 NOT NULL CONSTRAINT DF_TDDCChangeRequest_Create DEFAULT(SYSUTCDATETIME()),
            UpdateDate datetime2 NULL,
            CONSTRAINT FK_TDDCChangeRequest_Document FOREIGN KEY(DocumentID) REFERENCES dbo.TDDCDocument(DocumentID),
            CONSTRAINT FK_TDDCChangeRequest_Revision FOREIGN KEY(RevisionID) REFERENCES dbo.TDDCRevision(RevisionID),
            CONSTRAINT UQ_TDDCChangeRequest_Revision UNIQUE(CompanyID, RevisionID),
            CONSTRAINT CK_TDDCChangeRequest_Type CHECK(RequestType IN(N'NEW',N'CHANGE',N'WITHDRAW')),
            CONSTRAINT CK_TDDCChangeRequest_Status CHECK(StatusCode IN(N'DRAFT',N'SUBMITTED',N'COMPLETED',N'CANCELLED'))
        );
    END;
    IF OBJECT_ID(N'dbo.TDDCChangeRequestReference',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDDCChangeRequestReference (
            ChangeRequestID bigint NOT NULL,
            RelatedDocumentID bigint NOT NULL,
            RelatedRevisionID bigint NULL,
            CONSTRAINT PK_TDDCChangeRequestReference PRIMARY KEY(ChangeRequestID,RelatedDocumentID),
            CONSTRAINT FK_TDDCChangeReference_Request FOREIGN KEY(ChangeRequestID) REFERENCES dbo.TDDCChangeRequest(ChangeRequestID),
            CONSTRAINT FK_TDDCChangeReference_Document FOREIGN KEY(RelatedDocumentID) REFERENCES dbo.TDDCDocument(DocumentID),
            CONSTRAINT FK_TDDCChangeReference_Revision FOREIGN KEY(RelatedRevisionID) REFERENCES dbo.TDDCRevision(RevisionID)
        );
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
