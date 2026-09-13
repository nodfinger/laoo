SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDTMAttendancePeriodScheme', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAttendancePeriodScheme
    (
        AttendancePeriodSchemeID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMAttendancePeriodScheme PRIMARY KEY,
        CompanyID bigint NOT NULL,
        SchemeCode varchar(30) NOT NULL,
        SchemeName nvarchar(200) NOT NULL,
        DescriptionText nvarchar(500) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMAttendancePeriodScheme_Active DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendancePeriodScheme_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDTMAttendancePeriodScheme_Code UNIQUE (CompanyID, SchemeCode)
    );
END;

IF OBJECT_ID(N'dbo.TDTMAttendancePeriodSchemeVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAttendancePeriodSchemeVersion
    (
        AttendancePeriodSchemeVersionID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMAttendancePeriodSchemeVersion PRIMARY KEY,
        AttendancePeriodSchemeID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        PatternCode varchar(30) NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        CutOffDay tinyint NULL,
        IntervalCount smallint NULL,
        IntervalUnitCode varchar(10) NULL,
        AnchorDate date NULL,
        BranchReviewDueDays smallint NOT NULL CONSTRAINT DF_TDTMAttendancePeriodSchemeVersion_BranchDue DEFAULT (3),
        FinalizeDueDays smallint NOT NULL CONSTRAINT DF_TDTMAttendancePeriodSchemeVersion_FinalizeDue DEFAULT (7),
        IsActive bit NOT NULL CONSTRAINT DF_TDTMAttendancePeriodSchemeVersion_Active DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendancePeriodSchemeVersion_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMAttendancePeriodSchemeVersion_Scheme FOREIGN KEY (AttendancePeriodSchemeID)
            REFERENCES dbo.TDTMAttendancePeriodScheme(AttendancePeriodSchemeID),
        CONSTRAINT CK_TDTMAttendancePeriodSchemeVersion_Pattern CHECK (PatternCode IN ('CALENDAR_MONTH','CUT_OFF_DAY','FIXED_INTERVAL','CUSTOM_CALENDAR')),
        CONSTRAINT CK_TDTMAttendancePeriodSchemeVersion_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT CK_TDTMAttendancePeriodSchemeVersion_CutOff CHECK (CutOffDay IS NULL OR CutOffDay BETWEEN 1 AND 27),
        CONSTRAINT CK_TDTMAttendancePeriodSchemeVersion_Interval CHECK (IntervalCount IS NULL OR IntervalCount > 0),
        CONSTRAINT CK_TDTMAttendancePeriodSchemeVersion_Unit CHECK (IntervalUnitCode IS NULL OR IntervalUnitCode IN ('DAY','WEEK')),
        CONSTRAINT UQ_TDTMAttendancePeriodSchemeVersion_Start UNIQUE (AttendancePeriodSchemeID, EffectiveFrom)
    );
    CREATE UNIQUE INDEX UX_TDTMAttendancePeriodSchemeVersion_Open
        ON dbo.TDTMAttendancePeriodSchemeVersion(AttendancePeriodSchemeID)
        WHERE EffectiveTo IS NULL AND IsActive = 1;
END;

IF OBJECT_ID(N'dbo.TDTMAttendancePeriod', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAttendancePeriod
    (
        AttendancePeriodID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendancePeriod PRIMARY KEY,
        CompanyID bigint NOT NULL,
        AttendancePeriodSchemeID bigint NOT NULL,
        AttendancePeriodSchemeVersionID bigint NOT NULL,
        PeriodStartDate date NOT NULL,
        PeriodEndDate date NOT NULL,
        PeriodStatusCode varchar(20) NOT NULL CONSTRAINT DF_TDTMAttendancePeriod_Status DEFAULT ('OPEN'),
        FinalResultVersion int NOT NULL CONSTRAINT DF_TDTMAttendancePeriod_ResultVersion DEFAULT (0),
        FinalizedDate datetime2(3) NULL,
        FinalizedByUserID bigint NULL,
        ReopenedDate datetime2(3) NULL,
        ReopenedByUserID bigint NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendancePeriod_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMAttendancePeriod_Scheme FOREIGN KEY (AttendancePeriodSchemeID)
            REFERENCES dbo.TDTMAttendancePeriodScheme(AttendancePeriodSchemeID),
        CONSTRAINT FK_TDTMAttendancePeriod_Version FOREIGN KEY (AttendancePeriodSchemeVersionID)
            REFERENCES dbo.TDTMAttendancePeriodSchemeVersion(AttendancePeriodSchemeVersionID),
        CONSTRAINT CK_TDTMAttendancePeriod_Date CHECK (PeriodEndDate >= PeriodStartDate),
        CONSTRAINT CK_TDTMAttendancePeriod_Status CHECK (PeriodStatusCode IN ('OPEN','FINALIZED')),
        CONSTRAINT CK_TDTMAttendancePeriod_Finalized CHECK
            ((PeriodStatusCode='OPEN' AND FinalizedDate IS NULL AND FinalizedByUserID IS NULL) OR
             (PeriodStatusCode='FINALIZED' AND FinalizedDate IS NOT NULL AND FinalizedByUserID IS NOT NULL)),
        CONSTRAINT UQ_TDTMAttendancePeriod_Range UNIQUE (CompanyID, AttendancePeriodSchemeID, PeriodStartDate, PeriodEndDate)
    );
    CREATE INDEX IX_TDTMAttendancePeriod_Resolve
        ON dbo.TDTMAttendancePeriod(CompanyID, AttendancePeriodSchemeID, PeriodStartDate, PeriodEndDate, PeriodStatusCode);
END;

IF OBJECT_ID(N'dbo.TDTMEmployeeAttendancePeriodAssignment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMEmployeeAttendancePeriodAssignment
    (
        EmployeeAttendancePeriodAssignmentID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMEmployeeAttendancePeriodAssignment PRIMARY KEY,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        AttendancePeriodSchemeID bigint NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        AssignmentSourceCode varchar(20) NOT NULL,
        Reason nvarchar(1000) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMEmployeeAttendancePeriodAssignment_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMEmployeeAttendancePeriodAssignment_Scheme FOREIGN KEY (AttendancePeriodSchemeID)
            REFERENCES dbo.TDTMAttendancePeriodScheme(AttendancePeriodSchemeID),
        CONSTRAINT CK_TDTMEmployeeAttendancePeriodAssignment_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT CK_TDTMEmployeeAttendancePeriodAssignment_Source CHECK (AssignmentSourceCode IN ('DEFAULT','BULK','MANUAL')),
        CONSTRAINT UQ_TDTMEmployeeAttendancePeriodAssignment_Start UNIQUE (CompanyID, EmployeeID, EffectiveFrom)
    );
    CREATE UNIQUE INDEX UX_TDTMEmployeeAttendancePeriodAssignment_Open
        ON dbo.TDTMEmployeeAttendancePeriodAssignment(CompanyID, EmployeeID) WHERE EffectiveTo IS NULL;
    CREATE INDEX IX_TDTMEmployeeAttendancePeriodAssignment_Resolve
        ON dbo.TDTMEmployeeAttendancePeriodAssignment(CompanyID, EmployeeID, EffectiveFrom, EffectiveTo);
END;

IF OBJECT_ID(N'dbo.TDTMDefaultAttendancePeriodSchemeVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMDefaultAttendancePeriodSchemeVersion
    (
        DefaultAttendancePeriodSchemeVersionID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMDefaultAttendancePeriodSchemeVersion PRIMARY KEY,
        CompanyID bigint NOT NULL,
        AttendancePeriodSchemeID bigint NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMDefaultAttendancePeriodSchemeVersion_Active DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMDefaultAttendancePeriodSchemeVersion_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMDefaultAttendancePeriodSchemeVersion_Scheme FOREIGN KEY (AttendancePeriodSchemeID)
            REFERENCES dbo.TDTMAttendancePeriodScheme(AttendancePeriodSchemeID),
        CONSTRAINT CK_TDTMDefaultAttendancePeriodSchemeVersion_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT UQ_TDTMDefaultAttendancePeriodSchemeVersion_Start UNIQUE (CompanyID, EffectiveFrom)
    );
    CREATE UNIQUE INDEX UX_TDTMDefaultAttendancePeriodSchemeVersion_Open
        ON dbo.TDTMDefaultAttendancePeriodSchemeVersion(CompanyID) WHERE EffectiveTo IS NULL AND IsActive=1;
END;

IF OBJECT_ID(N'dbo.TDTMAttendancePeriodBranchReview', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAttendancePeriodBranchReview
    (
        AttendancePeriodBranchReviewID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMAttendancePeriodBranchReview PRIMARY KEY,
        AttendancePeriodID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        BranchID bigint NOT NULL,
        ReviewStatusCode varchar(20) NOT NULL CONSTRAINT DF_TDTMAttendancePeriodBranchReview_Status DEFAULT ('PENDING'),
        ReviewedDate datetime2(3) NULL,
        ReviewedByUserID bigint NULL,
        Remark nvarchar(1000) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendancePeriodBranchReview_CreateDate DEFAULT (sysdatetime()),
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMAttendancePeriodBranchReview_Period FOREIGN KEY (AttendancePeriodID)
            REFERENCES dbo.TDTMAttendancePeriod(AttendancePeriodID),
        CONSTRAINT CK_TDTMAttendancePeriodBranchReview_Status CHECK (ReviewStatusCode IN ('PENDING','REVIEWED')),
        CONSTRAINT UQ_TDTMAttendancePeriodBranchReview UNIQUE (AttendancePeriodID, BranchID)
    );
END;

IF OBJECT_ID(N'dbo.TDTMAttendancePeriodAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAttendancePeriodAudit
    (
        AttendancePeriodAuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendancePeriodAudit PRIMARY KEY,
        CompanyID bigint NOT NULL,
        AttendancePeriodID bigint NULL,
        ActionCode varchar(30) NOT NULL,
        BeforeJson nvarchar(max) NULL,
        AfterJson nvarchar(max) NULL,
        Reason nvarchar(1000) NULL,
        ActorUserID bigint NOT NULL,
        OccurredDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendancePeriodAudit_OccurredDate DEFAULT (sysdatetime()),
        CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMAttendancePeriodAudit_Correlation DEFAULT (newid()),
        CONSTRAINT CK_TDTMAttendancePeriodAudit_Before CHECK (BeforeJson IS NULL OR ISJSON(BeforeJson)=1),
        CONSTRAINT CK_TDTMAttendancePeriodAudit_After CHECK (AfterJson IS NULL OR ISJSON(AfterJson)=1)
    );
    CREATE INDEX IX_TDTMAttendancePeriodAudit_Period
        ON dbo.TDTMAttendancePeriodAudit(CompanyID, AttendancePeriodID, OccurredDate DESC);
END;
