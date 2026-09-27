SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMVisitorHostConfirmation', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMVisitorHostConfirmation
    (
        VisitorHostConfirmationID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDTMVisitorHostConfirmation PRIMARY KEY,
        CompanyID bigint NOT NULL,
        VisitorVisitID bigint NOT NULL,
        ConfirmationResultCode varchar(20) NOT NULL,
        ConfirmationNote nvarchar(1000) NULL,
        ConfirmedByUserID bigint NOT NULL,
        ConfirmedByNameSnapshot nvarchar(200) NOT NULL,
        ConfirmedDate datetime2(3) NOT NULL
            CONSTRAINT DF_TDTMVisitorHostConfirmation_ConfirmedDate DEFAULT(SYSUTCDATETIME()),
        CreateDate datetime2(3) NOT NULL
            CONSTRAINT DF_TDTMVisitorHostConfirmation_CreateDate DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT UQ_TDTMVisitorHostConfirmation_Visit UNIQUE(VisitorVisitID),
        CONSTRAINT FK_TDTMVisitorHostConfirmation_Visit FOREIGN KEY(VisitorVisitID)
            REFERENCES dbo.TDTMVisitorVisit(VisitorVisitID),
        CONSTRAINT CK_TDTMVisitorHostConfirmation_Result
            CHECK(ConfirmationResultCode IN('MET','NOT_MET'))
    );
    CREATE INDEX IX_TDTMVisitorHostConfirmation_CompanyVisit
        ON dbo.TDTMVisitorHostConfirmation(CompanyID,VisitorVisitID);
END;

COMMIT TRANSACTION;
