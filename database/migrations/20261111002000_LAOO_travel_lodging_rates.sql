SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code=N'016' AND Name=N'ระดับตำแหน่งงาน')
    THROW 54070, N'Job position level master group was not found.', 1;

IF OBJECT_ID(N'dbo.TDSTTravelLodgingRate',N'U') IS NULL
    CREATE TABLE dbo.TDSTTravelLodgingRate (
        CompanyID bigint NOT NULL,
        PositionLevelCode nvarchar(10) NOT NULL,
        Amount decimal(12,2) NOT NULL CHECK (Amount>=0),
        UpdateBy bigint NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_TravelLodgingRate_UpdateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TravelLodgingRate PRIMARY KEY (CompanyID, PositionLevelCode)
    );
