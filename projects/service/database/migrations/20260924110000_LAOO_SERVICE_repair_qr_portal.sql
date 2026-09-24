SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADServiceRequestQrPortal', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADServiceRequestQrPortal
    (
        ServiceRequestQrPortalID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADServiceRequestQrPortal PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ItemInstanceID bigint NOT NULL,
        QrToken nvarchar(100) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADServiceRequestQrPortal_IsActive DEFAULT(1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDADServiceRequestQrPortal_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADServiceRequestQrPortal_Company_Instance UNIQUE(CompanyID,ItemInstanceID),
        CONSTRAINT UQ_TDADServiceRequestQrPortal_Token UNIQUE(QrToken),
        CONSTRAINT FK_TDADServiceRequestQrPortal_ItemInstance FOREIGN KEY(ItemInstanceID) REFERENCES dbo.TDIVItemInstance(ItemInstanceID)
    );
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDADServiceRequestQrPortal') AND name=N'IX_TDADServiceRequestQrPortal_Company_Active')
    CREATE INDEX IX_TDADServiceRequestQrPortal_Company_Active ON dbo.TDADServiceRequestQrPortal(CompanyID,IsActive,ItemInstanceID);

COMMIT TRANSACTION;
