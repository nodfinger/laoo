SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @LockResult int;
EXEC @LockResult = sys.sp_getapplock
    @Resource = N'LAOO_SCHEMA_MIGRATION',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 60000;

IF @LockResult < 0
    THROW 52100, 'Cannot acquire the LAOO schema migration lock.', 1;

IF OBJECT_ID(N'dbo.TDSTSchemaMigration', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTSchemaMigration
    (
        MigrationID nvarchar(200) NOT NULL,
        ProjectCode nvarchar(50) NOT NULL,
        Checksum char(64) NOT NULL,
        AppliedUtc datetime2(3) NOT NULL,
        AppliedBy nvarchar(128) NOT NULL,
        SourceMachine nvarchar(128) NOT NULL,
        CONSTRAINT PK_TDSTSchemaMigration PRIMARY KEY (MigrationID)
    );

    CREATE INDEX IX_TDSTSchemaMigration_ProjectCode_AppliedUtc
        ON dbo.TDSTSchemaMigration(ProjectCode, AppliedUtc DESC);
END;

COMMIT TRANSACTION;
