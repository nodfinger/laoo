SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMPayrollExportProfile', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMPayrollExportProfile
    (
        PayrollExportProfileID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMPayrollExportProfile PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ProfileCode varchar(50) NOT NULL,
        ProfileName nvarchar(200) NOT NULL,
        FormatCode varchar(20) NOT NULL,
        DelimiterCode varchar(10) NOT NULL CONSTRAINT DF_TDTMPayrollExportProfile_Delimiter DEFAULT('|'),
        EncodingCode varchar(20) NOT NULL CONSTRAINT DF_TDTMPayrollExportProfile_Encoding DEFAULT('UTF8'),
        IncludeHeader bit NOT NULL CONSTRAINT DF_TDTMPayrollExportProfile_Header DEFAULT(1),
        DateFormat varchar(30) NOT NULL CONSTRAINT DF_TDTMPayrollExportProfile_DateFormat DEFAULT('yyyy-MM-dd'),
        ColumnMapJson nvarchar(max) NOT NULL CONSTRAINT DF_TDTMPayrollExportProfile_Columns
            DEFAULT(N'["EmployeeCode","FullName","WorkDayCount","CompleteDayCount","LeaveDayCount","ScheduledWorkMinutes","ActualWorkMinutes","LateMinutes","EarlyMinutes"]'),
        IsActive bit NOT NULL CONSTRAINT DF_TDTMPayrollExportProfile_Active DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMPayrollExportProfile_CreateDate DEFAULT(sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMPayrollExportProfile_Format CHECK(FormatCode IN('EXCEL','TEXT')),
        CONSTRAINT CK_TDTMPayrollExportProfile_Encoding CHECK(EncodingCode IN('UTF8','UTF8_BOM','WINDOWS_874')),
        CONSTRAINT UQ_TDTMPayrollExportProfile_Code UNIQUE(CompanyID, ProfileCode)
    );
END;

IF OBJECT_ID(N'dbo.TDTMPayrollExportBatch', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMPayrollExportBatch
    (
        PayrollExportBatchID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMPayrollExportBatch PRIMARY KEY,
        CompanyID bigint NOT NULL,
        AttendancePeriodID bigint NOT NULL,
        FinalResultVersion int NOT NULL,
        PayrollExportProfileID bigint NOT NULL,
        FormatCode varchar(20) NOT NULL,
        StatusCode varchar(20) NOT NULL,
        FileName nvarchar(260) NULL,
        FileRelativePath nvarchar(500) NULL,
        ContentHash varbinary(32) NULL,
        TotalRows int NOT NULL CONSTRAINT DF_TDTMPayrollExportBatch_TotalRows DEFAULT(0),
        GeneratedDate datetime2(3) NULL,
        GeneratedBy bigint NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMPayrollExportBatch_CreateDate DEFAULT(sysdatetime()),
        CreateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMPayrollExportBatch_Period FOREIGN KEY(AttendancePeriodID) REFERENCES dbo.TDTMAttendancePeriod(AttendancePeriodID),
        CONSTRAINT FK_TDTMPayrollExportBatch_Profile FOREIGN KEY(PayrollExportProfileID) REFERENCES dbo.TDTMPayrollExportProfile(PayrollExportProfileID),
        CONSTRAINT CK_TDTMPayrollExportBatch_Format CHECK(FormatCode IN('EXCEL','TEXT')),
        CONSTRAINT CK_TDTMPayrollExportBatch_Status CHECK(StatusCode IN('PREVIEW','GENERATED','FAILED')),
        CONSTRAINT CK_TDTMPayrollExportBatch_TotalRows CHECK(TotalRows >= 0)
    );
    CREATE INDEX IX_TDTMPayrollExportBatch_Period ON dbo.TDTMPayrollExportBatch(CompanyID, AttendancePeriodID, CreateDate DESC);
END;

IF OBJECT_ID(N'dbo.TDTMPayrollExportBatchRow', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMPayrollExportBatchRow
    (
        PayrollExportBatchRowID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMPayrollExportBatchRow PRIMARY KEY,
        PayrollExportBatchID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        EmployeeCode nvarchar(100) NOT NULL,
        FullName nvarchar(300) NOT NULL,
        WorkDayCount int NOT NULL,
        CompleteDayCount int NOT NULL,
        UnresolvedDayCount int NOT NULL,
        LeaveDayCount int NOT NULL,
        ScheduledWorkMinutes int NOT NULL,
        ActualWorkMinutes int NOT NULL,
        LateMinutes int NOT NULL,
        EarlyMinutes int NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMPayrollExportBatchRow_CreateDate DEFAULT(sysdatetime()),
        CONSTRAINT FK_TDTMPayrollExportBatchRow_Batch FOREIGN KEY(PayrollExportBatchID) REFERENCES dbo.TDTMPayrollExportBatch(PayrollExportBatchID),
        CONSTRAINT CK_TDTMPayrollExportBatchRow_Counts CHECK(WorkDayCount >= 0 AND CompleteDayCount >= 0 AND UnresolvedDayCount >= 0 AND LeaveDayCount >= 0),
        CONSTRAINT CK_TDTMPayrollExportBatchRow_Minutes CHECK(ScheduledWorkMinutes >= 0 AND ActualWorkMinutes >= 0 AND LateMinutes >= 0 AND EarlyMinutes >= 0),
        CONSTRAINT UQ_TDTMPayrollExportBatchRow_Employee UNIQUE(PayrollExportBatchID, EmployeeID)
    );
END;

COMMIT TRANSACTION;
