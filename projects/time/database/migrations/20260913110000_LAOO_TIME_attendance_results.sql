-- Canonical attendance import and open-period calculation results.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDTMAttendanceImportBatch', N'U') IS NULL
    CREATE TABLE dbo.TDTMAttendanceImportBatch
    (
        AttendanceImportBatchID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendanceImportBatch PRIMARY KEY,
        CompanyID bigint NOT NULL,
        SourceCode varchar(50) NOT NULL,
        IdempotencyKey nvarchar(100) NOT NULL,
        EventCount int NOT NULL,
        AcceptedCount int NOT NULL,
        SkippedCount int NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendanceImportBatch_CreateDate DEFAULT(sysdatetime()),
        CreateBy bigint NULL,
        CONSTRAINT CK_TDTMAttendanceImportBatch_Count CHECK(EventCount >= 0 AND AcceptedCount >= 0 AND SkippedCount >= 0),
        CONSTRAINT UQ_TDTMAttendanceImportBatch_Key UNIQUE(CompanyID, IdempotencyKey)
    );

    IF OBJECT_ID(N'dbo.TDTMAttendanceEvent', N'U') IS NULL
    CREATE TABLE dbo.TDTMAttendanceEvent
    (
        AttendanceEventID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendanceEvent PRIMARY KEY,
        AttendanceImportBatchID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        SourceCode varchar(50) NOT NULL,
        SourceEventID nvarchar(150) NOT NULL,
        DeviceCode nvarchar(100) NOT NULL,
        EventDateTime datetime2(3) NOT NULL,
        PayloadHash varbinary(32) NOT NULL,
        EventFingerprint varbinary(32) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendanceEvent_CreateDate DEFAULT(sysdatetime()),
        CreateBy bigint NULL,
        CONSTRAINT FK_TDTMAttendanceEvent_Batch FOREIGN KEY(AttendanceImportBatchID) REFERENCES dbo.TDTMAttendanceImportBatch(AttendanceImportBatchID),
        CONSTRAINT UQ_TDTMAttendanceEvent_Fingerprint UNIQUE(CompanyID, EventFingerprint)
    );
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceEvent') AND name=N'IX_TDTMAttendanceEvent_Resolve')
        CREATE INDEX IX_TDTMAttendanceEvent_Resolve ON dbo.TDTMAttendanceEvent(CompanyID, EmployeeID, EventDateTime) INCLUDE(AttendanceEventID);

    IF OBJECT_ID(N'dbo.TDTMAttendanceResult', N'U') IS NULL
    CREATE TABLE dbo.TDTMAttendanceResult
    (
        AttendanceResultID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendanceResult PRIMARY KEY,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        WorkDate date NOT NULL,
        ShiftTemplateVersionID bigint NULL,
        ResultVersion int NOT NULL,
        IsCurrent bit NOT NULL CONSTRAINT DF_TDTMAttendanceResult_Current DEFAULT(1),
        StatusCode varchar(20) NOT NULL,
        ScheduledWorkMinutes int NOT NULL,
        ActualWorkMinutes int NOT NULL,
        LateMinutes int NOT NULL,
        EarlyMinutes int NOT NULL,
        UnresolvedReason nvarchar(1000) NULL,
        CalculatedDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendanceResult_CalculatedDate DEFAULT(sysdatetime()),
        CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMAttendanceResult_Correlation DEFAULT(newid()),
        CreateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMAttendanceResult_Status CHECK(StatusCode IN('COMPLETE','UNRESOLVED','DAY_OFF')),
        CONSTRAINT CK_TDTMAttendanceResult_Minutes CHECK(ScheduledWorkMinutes >= 0 AND ActualWorkMinutes >= 0 AND LateMinutes >= 0 AND EarlyMinutes >= 0),
        CONSTRAINT UQ_TDTMAttendanceResult_Version UNIQUE(CompanyID, EmployeeID, WorkDate, ResultVersion)
    );
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceResult') AND name=N'UX_TDTMAttendanceResult_Current')
        CREATE UNIQUE INDEX UX_TDTMAttendanceResult_Current ON dbo.TDTMAttendanceResult(CompanyID, EmployeeID, WorkDate) WHERE IsCurrent=1;

    IF OBJECT_ID(N'dbo.TDTMAttendanceSessionResult', N'U') IS NULL
    CREATE TABLE dbo.TDTMAttendanceSessionResult
    (
        AttendanceSessionResultID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendanceSessionResult PRIMARY KEY,
        AttendanceResultID bigint NOT NULL,
        AttendanceSessionRuleID bigint NOT NULL,
        SequenceNo int NOT NULL,
        SessionStatusCode varchar(20) NOT NULL,
        ActualInDateTime datetime2(3) NULL,
        ActualOutDateTime datetime2(3) NULL,
        WorkMinutes int NOT NULL,
        LateMinutes int NOT NULL,
        EarlyMinutes int NOT NULL,
        CONSTRAINT FK_TDTMAttendanceSessionResult_Result FOREIGN KEY(AttendanceResultID) REFERENCES dbo.TDTMAttendanceResult(AttendanceResultID),
        CONSTRAINT FK_TDTMAttendanceSessionResult_Rule FOREIGN KEY(AttendanceSessionRuleID) REFERENCES dbo.TDTMAttendanceSessionRule(AttendanceSessionRuleID),
        CONSTRAINT CK_TDTMAttendanceSessionResult_Status CHECK(SessionStatusCode IN('COMPLETE','UNRESOLVED')),
        CONSTRAINT CK_TDTMAttendanceSessionResult_Minutes CHECK(WorkMinutes >= 0 AND LateMinutes >= 0 AND EarlyMinutes >= 0),
        CONSTRAINT UQ_TDTMAttendanceSessionResult_Sequence UNIQUE(AttendanceResultID, SequenceNo)
    );

    IF OBJECT_ID(N'dbo.TR_TDTMAttendanceEvent_Immutable', N'TR') IS NULL
        EXEC(N'CREATE TRIGGER dbo.TR_TDTMAttendanceEvent_Immutable ON dbo.TDTMAttendanceEvent INSTEAD OF UPDATE,DELETE AS THROW 52601,N''Attendance events are immutable.'',1;');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
