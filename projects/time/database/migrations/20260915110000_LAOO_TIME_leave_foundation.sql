SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
    LAOO_TIME leave foundation.

    Center/Core owns the menu, route and permission bootstrap.  This migration
    deliberately owns only Time data and reuses dbo.TDTMRequest, workflow
    snapshots, decisions, edit logs and notification outbox from foundation.
*/

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDTMRequest', N'U') IS NULL
        THROW 52600, N'LAOO_TIME request foundation is required before leave foundation.', 1;

    IF OBJECT_ID(N'dbo.TDTMLeaveType', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMLeaveType
        (
            LeaveTypeID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMLeaveType PRIMARY KEY,
            CompanyID bigint NOT NULL,
            LeaveTypeCode varchar(50) NOT NULL,
            LeaveTypeName nvarchar(200) NOT NULL,
            UnitCode varchar(10) NOT NULL,
            IsPaid bit NOT NULL CONSTRAINT DF_TDTMLeaveType_IsPaid DEFAULT(1),
            RequireRemark bit NOT NULL CONSTRAINT DF_TDTMLeaveType_RequireRemark DEFAULT(0),
            RequireEvidence bit NOT NULL CONSTRAINT DF_TDTMLeaveType_RequireEvidence DEFAULT(0),
            IsActive bit NOT NULL CONSTRAINT DF_TDTMLeaveType_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMLeaveType_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT UQ_TDTMLeaveType_Code UNIQUE(CompanyID, LeaveTypeCode),
            CONSTRAINT CK_TDTMLeaveType_Unit CHECK(UnitCode IN('DAY','MINUTE'))
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMLeaveEntitlementPolicyVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMLeaveEntitlementPolicyVersion
        (
            LeaveEntitlementPolicyVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMLeaveEntitlementPolicyVersion PRIMARY KEY,
            CompanyID bigint NOT NULL,
            LeaveTypeID bigint NOT NULL,
            PolicyName nvarchar(200) NOT NULL,
            UnitCode varchar(10) NOT NULL,
            EntitlementQuantity decimal(18,4) NOT NULL,
            EligibilityRuleJson nvarchar(max) NULL,
            EffectiveFrom date NOT NULL,
            EffectiveTo date NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMLeaveEntitlementPolicyVersion_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMLeaveEntitlementPolicyVersion_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMLeaveEntitlementPolicyVersion_Type FOREIGN KEY(LeaveTypeID)
                REFERENCES dbo.TDTMLeaveType(LeaveTypeID),
            CONSTRAINT CK_TDTMLeaveEntitlementPolicyVersion_Unit CHECK(UnitCode IN('DAY','MINUTE')),
            CONSTRAINT CK_TDTMLeaveEntitlementPolicyVersion_Quantity CHECK(EntitlementQuantity >= 0),
            CONSTRAINT CK_TDTMLeaveEntitlementPolicyVersion_Date CHECK(EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
            CONSTRAINT CK_TDTMLeaveEntitlementPolicyVersion_Rule CHECK(EligibilityRuleJson IS NULL OR ISJSON(EligibilityRuleJson)=1),
            CONSTRAINT UQ_TDTMLeaveEntitlementPolicyVersion_Start UNIQUE(CompanyID, LeaveTypeID, EffectiveFrom)
        );
        CREATE UNIQUE INDEX UX_TDTMLeaveEntitlementPolicyVersion_Open
            ON dbo.TDTMLeaveEntitlementPolicyVersion(CompanyID, LeaveTypeID)
            WHERE EffectiveTo IS NULL AND IsActive=1;
    END;

    IF OBJECT_ID(N'dbo.TDTMLeaveEntitlementLedger', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMLeaveEntitlementLedger
        (
            LeaveEntitlementLedgerID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMLeaveEntitlementLedger PRIMARY KEY,
            CompanyID bigint NOT NULL,
            EmployeeID bigint NOT NULL,
            LeaveTypeID bigint NOT NULL,
            UnitCode varchar(10) NOT NULL,
            EntryTypeCode varchar(20) NOT NULL,
            Quantity decimal(18,4) NOT NULL,
            EffectiveDate date NOT NULL,
            RequestID bigint NULL,
            SourcePolicyVersionID bigint NULL,
            SupersedesLedgerID bigint NULL,
            Reason nvarchar(1000) NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMLeaveEntitlementLedger_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NOT NULL,
            CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMLeaveEntitlementLedger_CorrelationID DEFAULT(newid()),
            CONSTRAINT FK_TDTMLeaveEntitlementLedger_Type FOREIGN KEY(LeaveTypeID)
                REFERENCES dbo.TDTMLeaveType(LeaveTypeID),
            CONSTRAINT FK_TDTMLeaveEntitlementLedger_Request FOREIGN KEY(RequestID)
                REFERENCES dbo.TDTMRequest(RequestID),
            CONSTRAINT FK_TDTMLeaveEntitlementLedger_Policy FOREIGN KEY(SourcePolicyVersionID)
                REFERENCES dbo.TDTMLeaveEntitlementPolicyVersion(LeaveEntitlementPolicyVersionID),
            CONSTRAINT FK_TDTMLeaveEntitlementLedger_Supersedes FOREIGN KEY(SupersedesLedgerID)
                REFERENCES dbo.TDTMLeaveEntitlementLedger(LeaveEntitlementLedgerID),
            CONSTRAINT CK_TDTMLeaveEntitlementLedger_Unit CHECK(UnitCode IN('DAY','MINUTE')),
            CONSTRAINT CK_TDTMLeaveEntitlementLedger_Type CHECK(EntryTypeCode IN('GRANT','ADJUSTMENT','RESERVATION','RELEASE','USAGE','REVERSAL','EXPIRY')),
            CONSTRAINT CK_TDTMLeaveEntitlementLedger_Quantity CHECK(Quantity <> 0),
            CONSTRAINT UQ_TDTMLeaveEntitlementLedger_Correlation UNIQUE(CompanyID, CorrelationID)
        );
        CREATE INDEX IX_TDTMLeaveEntitlementLedger_Balance
            ON dbo.TDTMLeaveEntitlementLedger(CompanyID, EmployeeID, LeaveTypeID, EffectiveDate, LeaveEntitlementLedgerID)
            INCLUDE(UnitCode, EntryTypeCode, Quantity, RequestID);
    END;

    IF OBJECT_ID(N'dbo.TR_TDTMLeaveEntitlementLedger_Immutable', N'TR') IS NULL
        EXEC(N'CREATE TRIGGER dbo.TR_TDTMLeaveEntitlementLedger_Immutable ON dbo.TDTMLeaveEntitlementLedger INSTEAD OF UPDATE,DELETE AS THROW 52610,N''Leave entitlement ledger is immutable; add a reversing entry.'',1;');

    IF OBJECT_ID(N'dbo.TDTMLeaveRequest', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMLeaveRequest
        (
            RequestID bigint NOT NULL CONSTRAINT PK_TDTMLeaveRequest PRIMARY KEY,
            CompanyID bigint NOT NULL,
            SubjectEmployeeID bigint NOT NULL,
            LeaveTypeID bigint NOT NULL,
            UnitCode varchar(10) NOT NULL,
            StartWorkDate date NOT NULL,
            EndWorkDate date NOT NULL,
            RequestedQuantity decimal(18,4) NOT NULL,
            RequestRemark nvarchar(1000) NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMLeaveRequest_CreateDate DEFAULT(sysdatetime()),
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMLeaveRequest_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDTMRequest(RequestID),
            CONSTRAINT FK_TDTMLeaveRequest_Type FOREIGN KEY(LeaveTypeID) REFERENCES dbo.TDTMLeaveType(LeaveTypeID),
            CONSTRAINT CK_TDTMLeaveRequest_Unit CHECK(UnitCode IN('DAY','MINUTE')),
            CONSTRAINT CK_TDTMLeaveRequest_Date CHECK(EndWorkDate >= StartWorkDate),
            CONSTRAINT CK_TDTMLeaveRequest_Quantity CHECK(RequestedQuantity > 0)
        );
        CREATE INDEX IX_TDTMLeaveRequest_EmployeeDate
            ON dbo.TDTMLeaveRequest(CompanyID, SubjectEmployeeID, StartWorkDate, EndWorkDate, LeaveTypeID);
    END;

    IF OBJECT_ID(N'dbo.TDTMLeaveRequestDate', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMLeaveRequestDate
        (
            LeaveRequestDateID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMLeaveRequestDate PRIMARY KEY,
            RequestID bigint NOT NULL,
            CompanyID bigint NOT NULL,
            SubjectEmployeeID bigint NOT NULL,
            WorkDate date NOT NULL,
            StartMinute int NULL,
            EndMinute int NULL,
            RequestedQuantity decimal(18,4) NOT NULL,
            ScheduledNetMinutes int NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMLeaveRequestDate_CreateDate DEFAULT(sysdatetime()),
            CONSTRAINT FK_TDTMLeaveRequestDate_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDTMLeaveRequest(RequestID),
            CONSTRAINT CK_TDTMLeaveRequestDate_Window CHECK
                ((StartMinute IS NULL AND EndMinute IS NULL) OR (StartMinute >= 0 AND EndMinute > StartMinute AND EndMinute <= 1440)),
            CONSTRAINT CK_TDTMLeaveRequestDate_Quantity CHECK(RequestedQuantity > 0),
            CONSTRAINT CK_TDTMLeaveRequestDate_Scheduled CHECK(ScheduledNetMinutes IS NULL OR ScheduledNetMinutes >= 0),
            CONSTRAINT UQ_TDTMLeaveRequestDate_WorkDate UNIQUE(RequestID, WorkDate)
        );
        CREATE INDEX IX_TDTMLeaveRequestDate_Conflict
            ON dbo.TDTMLeaveRequestDate(CompanyID, SubjectEmployeeID, WorkDate, RequestID);
    END;

    IF OBJECT_ID(N'dbo.TDTMLeaveReservation', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMLeaveReservation
        (
            LeaveReservationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMLeaveReservation PRIMARY KEY,
            CompanyID bigint NOT NULL,
            RequestID bigint NOT NULL,
            EmployeeID bigint NOT NULL,
            LeaveTypeID bigint NOT NULL,
            UnitCode varchar(10) NOT NULL,
            ReservedQuantity decimal(18,4) NOT NULL,
            StatusCode varchar(20) NOT NULL CONSTRAINT DF_TDTMLeaveReservation_Status DEFAULT('ACTIVE'),
            ReservedLedgerID bigint NOT NULL,
            ReleasedLedgerID bigint NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMLeaveReservation_CreateDate DEFAULT(sysdatetime()),
            ResolvedDate datetime2(3) NULL,
            CONSTRAINT FK_TDTMLeaveReservation_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDTMLeaveRequest(RequestID),
            CONSTRAINT FK_TDTMLeaveReservation_Type FOREIGN KEY(LeaveTypeID) REFERENCES dbo.TDTMLeaveType(LeaveTypeID),
            CONSTRAINT FK_TDTMLeaveReservation_ReservedLedger FOREIGN KEY(ReservedLedgerID) REFERENCES dbo.TDTMLeaveEntitlementLedger(LeaveEntitlementLedgerID),
            CONSTRAINT FK_TDTMLeaveReservation_ReleasedLedger FOREIGN KEY(ReleasedLedgerID) REFERENCES dbo.TDTMLeaveEntitlementLedger(LeaveEntitlementLedgerID),
            CONSTRAINT CK_TDTMLeaveReservation_Unit CHECK(UnitCode IN('DAY','MINUTE')),
            CONSTRAINT CK_TDTMLeaveReservation_Quantity CHECK(ReservedQuantity > 0),
            CONSTRAINT CK_TDTMLeaveReservation_Status CHECK(StatusCode IN('ACTIVE','RELEASED','CONSUMED','EXPIRED')),
            CONSTRAINT UQ_TDTMLeaveReservation_Request UNIQUE(RequestID)
        );
        CREATE INDEX IX_TDTMLeaveReservation_Active
            ON dbo.TDTMLeaveReservation(CompanyID, EmployeeID, LeaveTypeID, StatusCode) INCLUDE(ReservedQuantity);
    END;

    IF OBJECT_ID(N'dbo.TDTMLeaveUsage', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMLeaveUsage
        (
            LeaveUsageID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMLeaveUsage PRIMARY KEY,
            CompanyID bigint NOT NULL,
            RequestID bigint NOT NULL,
            LeaveRequestDateID bigint NOT NULL,
            EmployeeID bigint NOT NULL,
            LeaveTypeID bigint NOT NULL,
            WorkDate date NOT NULL,
            UnitCode varchar(10) NOT NULL,
            UsedQuantity decimal(18,4) NOT NULL,
            UsageLedgerID bigint NOT NULL,
            SupersedesLeaveUsageID bigint NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMLeaveUsage_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NOT NULL,
            CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMLeaveUsage_CorrelationID DEFAULT(newid()),
            CONSTRAINT FK_TDTMLeaveUsage_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDTMLeaveRequest(RequestID),
            CONSTRAINT FK_TDTMLeaveUsage_RequestDate FOREIGN KEY(LeaveRequestDateID) REFERENCES dbo.TDTMLeaveRequestDate(LeaveRequestDateID),
            CONSTRAINT FK_TDTMLeaveUsage_Type FOREIGN KEY(LeaveTypeID) REFERENCES dbo.TDTMLeaveType(LeaveTypeID),
            CONSTRAINT FK_TDTMLeaveUsage_Ledger FOREIGN KEY(UsageLedgerID) REFERENCES dbo.TDTMLeaveEntitlementLedger(LeaveEntitlementLedgerID),
            CONSTRAINT FK_TDTMLeaveUsage_Supersedes FOREIGN KEY(SupersedesLeaveUsageID) REFERENCES dbo.TDTMLeaveUsage(LeaveUsageID),
            CONSTRAINT CK_TDTMLeaveUsage_Unit CHECK(UnitCode IN('DAY','MINUTE')),
            CONSTRAINT CK_TDTMLeaveUsage_Quantity CHECK(UsedQuantity > 0),
            CONSTRAINT UQ_TDTMLeaveUsage_Ledger UNIQUE(UsageLedgerID),
            CONSTRAINT UQ_TDTMLeaveUsage_Correlation UNIQUE(CompanyID, CorrelationID)
        );
        CREATE INDEX IX_TDTMLeaveUsage_EmployeeDate
            ON dbo.TDTMLeaveUsage(CompanyID, EmployeeID, WorkDate, LeaveTypeID);
    END;

    IF OBJECT_ID(N'dbo.TR_TDTMLeaveUsage_Immutable', N'TR') IS NULL
        EXEC(N'CREATE TRIGGER dbo.TR_TDTMLeaveUsage_Immutable ON dbo.TDTMLeaveUsage INSTEAD OF UPDATE,DELETE AS THROW 52611,N''Leave usage is immutable; create a superseding usage.'',1;');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
