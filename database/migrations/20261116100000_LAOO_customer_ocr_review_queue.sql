-- Customer origin describes how the customer was first created; existing
-- customers retain their origin when a new business card is linked to them.
IF COL_LENGTH(N'dbo.TDARCustomer', N'DataSource') IS NULL
BEGIN
    ALTER TABLE dbo.TDARCustomer ADD DataSource tinyint NOT NULL
        CONSTRAINT DF_TDARCustomer_DataSource DEFAULT (0) WITH VALUES;
END;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.TDARCustomer') AND name = N'CK_TDARCustomer_DataSource')
    EXEC(N'ALTER TABLE dbo.TDARCustomer WITH CHECK ADD CONSTRAINT CK_TDARCustomer_DataSource CHECK (DataSource IN (0, 1))');

IF OBJECT_ID(N'dbo.TDSTBusinessCardReviewQueue', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTBusinessCardReviewQueue (
        ReviewID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDSTBusinessCardReviewQueue PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ContactID bigint NOT NULL,
        CustomerID bigint NOT NULL,
        SubmittedBy bigint NOT NULL,
        SubmittedAt datetime2 NOT NULL CONSTRAINT DF_BusinessCardReviewQueue_SubmittedAt DEFAULT SYSUTCDATETIME(),
        ReviewedBy bigint NULL,
        ReviewedAt datetime2 NULL,
        CONSTRAINT CK_BusinessCardReviewQueue_Reviewed CHECK ((ReviewedBy IS NULL AND ReviewedAt IS NULL) OR (ReviewedBy IS NOT NULL AND ReviewedAt IS NOT NULL))
    );
    CREATE INDEX IX_BusinessCardReviewQueue_Pending ON dbo.TDSTBusinessCardReviewQueue (CompanyID, ReviewedAt, ReviewID DESC) INCLUDE (ContactID, CustomerID, SubmittedBy);
END;
