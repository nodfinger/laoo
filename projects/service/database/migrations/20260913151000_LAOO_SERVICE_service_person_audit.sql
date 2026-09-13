/* Immutable before/after audit for shared Person edits initiated by Service. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDADPerson',N'U') IS NULL
        THROW 52960,N'TDADPerson is required before Service Person audit.',1;

    IF OBJECT_ID(N'dbo.TDADServicePersonAudit',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDADServicePersonAudit
        (
            ServicePersonAuditID bigint IDENTITY(1,1) NOT NULL
                CONSTRAINT PK_TDADServicePersonAudit PRIMARY KEY,
            CompanyID bigint NOT NULL,
            PersonID bigint NOT NULL,
            ActionCode nvarchar(30) NOT NULL,
            BeforeData nvarchar(max) NULL,
            AfterData nvarchar(max) NULL,
            CreateDate datetime2(3) NOT NULL
                CONSTRAINT DF_TDADServicePersonAudit_CreateDate DEFAULT(SYSUTCDATETIME()),
            CreateBy bigint NULL,
            CONSTRAINT FK_TDADServicePersonAudit_Person FOREIGN KEY(CompanyID,PersonID)
                REFERENCES dbo.TDADPerson(CompanyID,PersonID),
            CONSTRAINT CK_TDADServicePersonAudit_Action CHECK(ActionCode IN(N'PERSON_UPDATE'))
        );
        CREATE INDEX IX_TDADServicePersonAudit_Company_Person_Date
            ON dbo.TDADServicePersonAudit(CompanyID,PersonID,CreateDate DESC);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
