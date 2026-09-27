-- Audit trail for administrator warranty corrections.
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDIVItemInstanceWarrantyHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDIVItemInstanceWarrantyHistory
    (
        ItemInstanceWarrantyHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDIVItemInstanceWarrantyHistory PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ItemInstanceWarrantyID bigint NOT NULL,
        ActionCode nvarchar(20) NOT NULL,
        OldWarrantyModeCode nvarchar(20) NULL,
        OldDurationMonths int NULL,
        OldStartDate date NULL,
        OldExpireDate date NULL,
        NewWarrantyModeCode nvarchar(20) NULL,
        NewDurationMonths int NULL,
        NewStartDate date NULL,
        NewExpireDate date NULL,
        Remark nvarchar(500) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDIVItemInstanceWarrantyHistory_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NOT NULL,
        CONSTRAINT FK_TDIVItemInstanceWarrantyHistory_Warranty FOREIGN KEY(ItemInstanceWarrantyID) REFERENCES dbo.TDIVItemInstanceWarranty(ItemInstanceWarrantyID),
        CONSTRAINT CK_TDIVItemInstanceWarrantyHistory_Action CHECK(ActionCode IN(N'OVERRIDE'))
    );
    CREATE INDEX IX_TDIVItemInstanceWarrantyHistory_Warranty ON dbo.TDIVItemInstanceWarrantyHistory(CompanyID,ItemInstanceWarrantyID,CreateDate);
END;
