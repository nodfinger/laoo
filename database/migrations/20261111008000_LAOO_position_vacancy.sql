SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTPositionVacancy',N'U') IS NULL
    CREATE TABLE dbo.TDSTPositionVacancy (
        CompanyID bigint NOT NULL,
        PositionCode nvarchar(10) NOT NULL,
        IsVacant bit NOT NULL CONSTRAINT DF_PositionVacancy_IsVacant DEFAULT 0,
        SubstituteEmployeeID bigint NULL,
        UpdateBy bigint NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_PositionVacancy_UpdateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_PositionVacancy PRIMARY KEY (CompanyID, PositionCode)
    );
