SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADResident', N'U') IS NULL
    THROW 53030, N'TDADResident is required.', 1;

IF COL_LENGTH(N'dbo.TDADResident', N'StartDate') IS NULL
    THROW 53031, N'TDADResident.StartDate is required.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id=OBJECT_ID(N'dbo.TDADResident')
      AND name=N'StartDate'
      AND is_nullable=0
)
    ALTER TABLE dbo.TDADResident ALTER COLUMN StartDate date NULL;