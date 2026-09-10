SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

BEGIN TRANSACTION;

DECLARE @LockResult int;
EXEC @LockResult = sys.sp_getapplock
    @Resource = N'LAOO_SCHEMA_MIGRATION',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 60000;

IF @LockResult < 0
    THROW 52400, N'Cannot acquire the LAOO schema migration lock.', 1;

IF OBJECT_ID(N'dbo.TDSTSchemaMigration', N'U') IS NULL
    THROW 52401, N'Run MIGRATION_LEDGER_SCHEMA.sql before this migration.', 1;

DECLARE @MigrationID nvarchar(200) = N'20260909100000_LAOO_branch_warehouse_user_access';

IF NOT EXISTS (SELECT 1 FROM dbo.TDSTSchemaMigration WHERE MigrationID=@MigrationID)
BEGIN
    IF COL_LENGTH(N'dbo.TDADBranch', N'AccessModeCode') IS NULL
    BEGIN
        ALTER TABLE dbo.TDADBranch
            ADD AccessModeCode nvarchar(20) NOT NULL
                CONSTRAINT DF_TDADBranch_AccessModeCode DEFAULT(N'ALL');

        -- Existing branches retain their current TDADUserBranch assignments.
        EXEC(N'UPDATE dbo.TDADBranch SET AccessModeCode=N''RESTRICTED'';');
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.check_constraints
        WHERE name=N'CK_TDADBranch_AccessModeCode'
    )
        EXEC(N'ALTER TABLE dbo.TDADBranch ADD CONSTRAINT CK_TDADBranch_AccessModeCode
            CHECK(AccessModeCode IN (N''ALL'',N''RESTRICTED''));');

    IF COL_LENGTH(N'dbo.TDIVWarehouse', N'AccessModeCode') IS NULL
        ALTER TABLE dbo.TDIVWarehouse
            ADD AccessModeCode nvarchar(20) NOT NULL
                CONSTRAINT DF_TDIVWarehouse_AccessModeCode DEFAULT(N'INHERIT');

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.check_constraints
        WHERE name=N'CK_TDIVWarehouse_AccessModeCode'
    )
        EXEC(N'ALTER TABLE dbo.TDIVWarehouse ADD CONSTRAINT CK_TDIVWarehouse_AccessModeCode
            CHECK(AccessModeCode IN (N''INHERIT'',N''RESTRICTED''));');

    IF OBJECT_ID(N'dbo.TDIVUserWarehouse', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDIVUserWarehouse
        (
            UserWarehouseID bigint IDENTITY(1,1) NOT NULL
                CONSTRAINT PK_TDIVUserWarehouse PRIMARY KEY,
            CompanyID bigint NOT NULL,
            WarehouseID bigint NOT NULL,
            UserID bigint NOT NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDIVUserWarehouse_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVUserWarehouse_CreateDate DEFAULT(SYSUTCDATETIME()),
            CreatedBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdatedBy bigint NULL,
            CONSTRAINT UQ_TDIVUserWarehouse_Company_Warehouse_User UNIQUE(CompanyID,WarehouseID,UserID),
            CONSTRAINT FK_TDIVUserWarehouse_Warehouse FOREIGN KEY(WarehouseID) REFERENCES dbo.TDIVWarehouse(WarehouseID),
            CONSTRAINT FK_TDIVUserWarehouse_User FOREIGN KEY(UserID) REFERENCES dbo.TDADUser(UserID)
        );

        CREATE INDEX IX_TDIVUserWarehouse_User_Access
            ON dbo.TDIVUserWarehouse(CompanyID,UserID,IsActive,WarehouseID);
    END;

    INSERT dbo.TDSTSchemaMigration
        (MigrationID,ProjectCode,Checksum,AppliedUtc,AppliedBy,SourceMachine)
    VALUES
        (@MigrationID,N'LAOO',CONVERT(char(64),HASHBYTES('SHA2_256',@MigrationID + N':v1'),2),
         SYSUTCDATETIME(),SUSER_SNAME(),HOST_NAME());
END;

COMMIT TRANSACTION;
