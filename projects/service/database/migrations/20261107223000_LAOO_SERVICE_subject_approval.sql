SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADServiceRequestSubject',N'U') IS NULL
    THROW 53620,N'Service request subject table is missing.',1;
IF COL_LENGTH(N'dbo.TDADServiceRequestSubject',N'RequiresApproval') IS NULL
    ALTER TABLE dbo.TDADServiceRequestSubject ADD RequiresApproval bit NOT NULL
      CONSTRAINT DF_ServiceRequestSubject_RequiresApproval DEFAULT (0) WITH VALUES;
