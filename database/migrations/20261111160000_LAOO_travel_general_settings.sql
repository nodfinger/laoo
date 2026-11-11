IF OBJECT_ID(N'dbo.TDSTTravelGeneralSettings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTTravelGeneralSettings (
        CompanyID bigint NOT NULL CONSTRAINT PK_TDSTTravelGeneralSettings PRIMARY KEY,
        DocumentExpiryDays int NULL CONSTRAINT CK_TravelDocumentExpiry CHECK (DocumentExpiryDays IS NULL OR DocumentExpiryDays >= 0),
        DocumentRevision nvarchar(100) NOT NULL CONSTRAINT DF_TravelDocumentRevision DEFAULT N'',
        Remark1 nvarchar(1000) NOT NULL CONSTRAINT DF_TravelRemark1 DEFAULT N'',
        Remark2 nvarchar(1000) NOT NULL CONSTRAINT DF_TravelRemark2 DEFAULT N'',
        Remark3 nvarchar(1000) NOT NULL CONSTRAINT DF_TravelRemark3 DEFAULT N'',
        Remark4 nvarchar(1000) NOT NULL CONSTRAINT DF_TravelRemark4 DEFAULT N'',
        Remark5 nvarchar(1000) NOT NULL CONSTRAINT DF_TravelRemark5 DEFAULT N'',
        UpdateBy bigint NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_TravelGeneralUpdateDate DEFAULT SYSUTCDATETIME()
    );
END;
