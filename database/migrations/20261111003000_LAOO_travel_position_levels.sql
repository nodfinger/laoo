SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTTravelPositionLevel', N'U') IS NULL
    CREATE TABLE dbo.TDSTTravelPositionLevel (
        CompanyID bigint NOT NULL,
        PositionCode nvarchar(10) NOT NULL,
        PositionLevelCode nvarchar(10) NOT NULL,
        UpdateBy bigint NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_TravelPositionLevel_UpdateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TravelPositionLevel PRIMARY KEY (CompanyID, PositionCode)
    );
