/* Customer-owned customer master for MenuCode 09001 / Scope CUSTOMER. */
IF OBJECT_ID(N'dbo.TDARCustomer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARCustomer
    (
        CustomerID       BIGINT IDENTITY(1,1) NOT NULL,
        CompanyID        BIGINT NOT NULL,
        CusCode          NVARCHAR(50) NOT NULL,
        CusShortCode     NVARCHAR(50) NULL,
        CusName          NVARCHAR(200) NOT NULL,
        CusAddress       NVARCHAR(1000) NULL,
        ProvCode         NVARCHAR(50) NULL,
        PostCode         NVARCHAR(20) NULL,
        StartDate        DATE NULL,
        CusGroupCode     NVARCHAR(50) NULL,
        BusinessTypeCode NVARCHAR(50) NULL,
        PriceLevelCode   NVARCHAR(50) NULL,
        Website          NVARCHAR(320) NULL,
        Phone            NVARCHAR(50) NULL,
        Email            NVARCHAR(320) NULL,
        ContName1       NVARCHAR(200) NULL,
        PositionName1   NVARCHAR(200) NULL,
        Phone1          NVARCHAR(50) NULL,
        Email1          NVARCHAR(320) NULL,
        ContName2       NVARCHAR(200) NULL,
        PositionName2   NVARCHAR(200) NULL,
        Phone2          NVARCHAR(50) NULL,
        Email2          NVARCHAR(320) NULL,
        IsActive        BIT NOT NULL CONSTRAINT DF_TDARCustomer_IsActive DEFAULT (1),
        CreateDate      DATETIME2(7) NOT NULL CONSTRAINT DF_TDARCustomer_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy        BIGINT NULL,
        UpdateDate      DATETIME2(7) NULL,
        UpdateBy        BIGINT NULL,
        CONSTRAINT PK_TDARCustomer PRIMARY KEY CLUSTERED (CustomerID),
        CONSTRAINT UQ_TDARCustomer_Company_CusCode UNIQUE (CompanyID, CusCode)
    );

    CREATE INDEX IX_TDARCustomer_Company_Name
        ON dbo.TDARCustomer (CompanyID, CusName);
    CREATE INDEX IX_TDARCustomer_Company_Filters
        ON dbo.TDARCustomer (CompanyID, CusGroupCode, BusinessTypeCode, ProvCode);
    CREATE UNIQUE INDEX UX_TDARCustomer_Company_ShortCode
        ON dbo.TDARCustomer (CompanyID, CusShortCode)
        WHERE CusShortCode IS NOT NULL;
END;
GO
