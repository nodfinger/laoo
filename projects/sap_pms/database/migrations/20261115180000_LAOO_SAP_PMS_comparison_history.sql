IF OBJECT_ID(N'dbo.TDPSComparisonHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDPSComparisonHistory
    (
        ComparisonHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDPSComparisonHistory PRIMARY KEY,
        CompanyID bigint NOT NULL,
        PmsFileName nvarchar(255) NOT NULL,
        PmsRecordCount int NOT NULL,
        SapFileName nvarchar(255) NOT NULL,
        SapRecordCount int NOT NULL,
        DateFrom date NULL,
        DateTo date NULL,
        ComparedByUserID bigint NOT NULL,
        ComparedByEmployeeID bigint NULL,
        ComparedAt datetime2(3) NOT NULL CONSTRAINT DF_TDPSComparisonHistory_ComparedAt DEFAULT SYSUTCDATETIME(),
        TotalCount int NOT NULL,
        NormalCount int NOT NULL,
        ProblemCount int NOT NULL,
        WaitingCount int NOT NULL,
        ProblemDocumentNumbers nvarchar(max) NULL,
        CONSTRAINT CK_TDPSComparisonHistory_Counts CHECK (PmsRecordCount>=0 AND SapRecordCount>=0 AND TotalCount>=0 AND NormalCount>=0 AND ProblemCount>=0 AND WaitingCount>=0 AND TotalCount=NormalCount+ProblemCount+WaitingCount),
        CONSTRAINT CK_TDPSComparisonHistory_Dates CHECK (DateFrom IS NULL OR DateTo IS NULL OR DateFrom<=DateTo)
    );
    CREATE INDEX IX_TDPSComparisonHistory_CompanyDate ON dbo.TDPSComparisonHistory(CompanyID, ComparedAt DESC, ComparisonHistoryID DESC);
END;
