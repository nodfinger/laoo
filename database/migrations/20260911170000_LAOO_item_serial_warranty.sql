-- Core item warranty defaults and per-serial warranty snapshots.
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDIVItemWarrantyPolicy', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemWarrantyPolicy
    (
        CompanyID bigint NOT NULL,
        ItemID bigint NOT NULL,
        CoverageTypeCode nvarchar(20) NOT NULL,
        WarrantyModeCode nvarchar(20) NOT NULL,
        DurationMonths int NULL,
        UpdateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVItemWarrantyPolicy_UpdateDate DEFAULT SYSUTCDATETIME(),
        UpdatedBy bigint NOT NULL,
        CONSTRAINT PK_TDIVItemWarrantyPolicy PRIMARY KEY(CompanyID, ItemID, CoverageTypeCode),
        CONSTRAINT FK_TDIVItemWarrantyPolicy_Item FOREIGN KEY(ItemID) REFERENCES dbo.TDIVItem(ItemID) ON DELETE CASCADE,
        CONSTRAINT CK_TDIVItemWarrantyPolicy_Coverage CHECK(CoverageTypeCode IN(N'SUPPLIER',N'CUSTOMER')),
        CONSTRAINT CK_TDIVItemWarrantyPolicy_Mode CHECK(WarrantyModeCode IN(N'NONE',N'LIFETIME',N'MONTHS')),
        CONSTRAINT CK_TDIVItemWarrantyPolicy_Duration CHECK((WarrantyModeCode=N'MONTHS' AND DurationMonths>0) OR (WarrantyModeCode<>N'MONTHS' AND DurationMonths IS NULL))
    );
END;

IF OBJECT_ID(N'dbo.TDIVItemInstanceWarranty', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemInstanceWarranty
    (
        ItemInstanceWarrantyID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVItemInstanceWarranty PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ItemInstanceID bigint NOT NULL,
        CoverageTypeCode nvarchar(20) NOT NULL,
        WarrantyModeCode nvarchar(20) NOT NULL,
        DurationMonths int NULL,
        StartDate date NOT NULL,
        ExpireDate date NULL,
        StartEventCode nvarchar(30) NOT NULL,
        SourceDocumentType nvarchar(30) NULL,
        SourceDocumentID bigint NULL,
        SourceDocumentDetailID bigint NULL,
        VoidedDate datetime2(3) NULL,
        VoidedBy bigint NULL,
        VoidRemark nvarchar(500) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVItemInstanceWarranty_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL,
        UpdateDate datetime2(3) NULL,
        UpdatedBy bigint NULL,
        OverrideRemark nvarchar(500) NULL,
        CONSTRAINT FK_TDIVItemInstanceWarranty_Instance FOREIGN KEY(ItemInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID),
        CONSTRAINT CK_TDIVItemInstanceWarranty_Coverage CHECK(CoverageTypeCode IN(N'SUPPLIER',N'CUSTOMER')),
        CONSTRAINT CK_TDIVItemInstanceWarranty_Mode CHECK(WarrantyModeCode IN(N'NONE',N'LIFETIME',N'MONTHS')),
        CONSTRAINT CK_TDIVItemInstanceWarranty_Duration CHECK((WarrantyModeCode=N'MONTHS' AND DurationMonths>0) OR (WarrantyModeCode<>N'MONTHS' AND DurationMonths IS NULL)),
        CONSTRAINT CK_TDIVItemInstanceWarranty_Expire CHECK((WarrantyModeCode=N'MONTHS' AND ExpireDate IS NOT NULL) OR (WarrantyModeCode<>N'MONTHS' AND ExpireDate IS NULL))
    );
    CREATE UNIQUE INDEX UX_TDIVItemInstanceWarranty_ActiveCoverage
        ON dbo.TDIVItemInstanceWarranty(CompanyID, ItemInstanceID, CoverageTypeCode)
        WHERE VoidedDate IS NULL;
    CREATE INDEX IX_TDIVItemInstanceWarranty_Instance ON dbo.TDIVItemInstanceWarranty(CompanyID, ItemInstanceID, VoidedDate);
END;

IF COL_LENGTH(N'dbo.TDIVDocumentSerialSelection', N'StartCustomerWarranty') IS NULL
    ALTER TABLE dbo.TDIVDocumentSerialSelection ADD StartCustomerWarranty bit NOT NULL CONSTRAINT DF_TDIVDocumentSerialSelection_StartCustomerWarranty DEFAULT 0;
