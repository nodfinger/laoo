/*
   Preserve the pre-existing Core purchasing schema when it does not match
   the Purchasing feature contract. The old tables are retained under an
   explicit legacy name; no request rows are discarded.
*/
IF OBJECT_ID(N'dbo.TDAPPurchaseRequest', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.TDAPPurchaseRequest', N'RequestID') IS NULL
BEGIN
    IF OBJECT_ID(N'dbo.TDAPPurchaseRequest_Legacy_20261113', N'U') IS NOT NULL
        THROW 51000, 'Legacy purchasing backup table already exists; inspect before applying this migration.', 1;

    IF OBJECT_ID(N'dbo.TDAPPurchaseRequestDetail', N'U') IS NOT NULL
       AND OBJECT_ID(N'dbo.TDAPPurchaseRequestDetail_Legacy_20261113', N'U') IS NOT NULL
        THROW 51001, 'Legacy purchasing detail backup table already exists; inspect before applying this migration.', 1;

    IF OBJECT_ID(N'dbo.TDAPPurchaseRequestDetail', N'U') IS NOT NULL
        EXEC sys.sp_rename N'dbo.TDAPPurchaseRequestDetail', N'TDAPPurchaseRequestDetail_Legacy_20261113';
    EXEC sys.sp_rename N'dbo.TDAPPurchaseRequest', N'TDAPPurchaseRequest_Legacy_20261113';
END;

IF OBJECT_ID(N'dbo.TDAPPurchaseRequest', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPPurchaseRequest
    (
        RequestID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPurchaseRequest_Feature PRIMARY KEY,
        CompanyID bigint NOT NULL,
        RequestNo nvarchar(50) NOT NULL,
        RequestDate date NOT NULL,
        RequesterUserID bigint NULL,
        DivisionID bigint NULL,
        DepartmentID bigint NULL,
        StatusCode nvarchar(30) NOT NULL CONSTRAINT DF_TDAPPurchaseRequest_Status_Feature DEFAULT N'DRAFT',
        ResponsibleUserID bigint NULL,
        Remark nvarchar(2000) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDAPPurchaseRequest_CreateDate_Feature DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        CONSTRAINT UQ_TDAPPurchaseRequest_Company_No_Feature UNIQUE (CompanyID, RequestNo),
        CONSTRAINT CK_TDAPPurchaseRequest_Status_Feature CHECK (StatusCode IN (N'DRAFT',N'SUBMITTED',N'IN_PROGRESS',N'COMPLETED',N'CANCELLED'))
    );
END;
IF OBJECT_ID(N'dbo.TDAPPurchaseRequestDetail', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPPurchaseRequestDetail
    (
        DetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPurchaseRequestDetail_Feature PRIMARY KEY,
        RequestID bigint NOT NULL,
        ItemText nvarchar(2000) NOT NULL,
        Quantity decimal(18,4) NULL,
        EstimatedMin decimal(18,2) NULL,
        EstimatedMax decimal(18,2) NULL,
        Remark nvarchar(2000) NULL,
        NeededDate date NULL,
        UrgencyLevel tinyint NOT NULL CONSTRAINT DF_TDAPPurchaseRequestDetail_Urgency_Feature DEFAULT 0,
        SortOrder int NOT NULL CONSTRAINT DF_TDAPPurchaseRequestDetail_Sort_Feature DEFAULT 1,
        CONSTRAINT FK_TDAPPurchaseRequestDetail_Request_Feature FOREIGN KEY (RequestID) REFERENCES dbo.TDAPPurchaseRequest(RequestID),
        CONSTRAINT CK_TDAPPurchaseRequestDetail_Urgency_Feature CHECK (UrgencyLevel IN (0,1,2)),
        CONSTRAINT CK_TDAPPurchaseRequestDetail_Estimate_Feature CHECK (EstimatedMin IS NULL OR EstimatedMax IS NULL OR EstimatedMin <= EstimatedMax)
    );
END;
IF OBJECT_ID(N'dbo.TDAPPurchaseRequestAttachment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDAPPurchaseRequestAttachment
    (
        AttachmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDAPPurchaseRequestAttachment_Feature PRIMARY KEY,
        RequestID bigint NOT NULL,
        DetailID bigint NOT NULL,
        FileName nvarchar(255) NOT NULL,
        StoredPath nvarchar(500) NOT NULL,
        ContentType nvarchar(100) NOT NULL,
        FileSize bigint NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDAPPurchaseRequestAttachment_CreateDate_Feature DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        CONSTRAINT FK_TDAPPurchaseRequestAttachment_Request_Feature FOREIGN KEY (RequestID) REFERENCES dbo.TDAPPurchaseRequest(RequestID),
        CONSTRAINT FK_TDAPPurchaseRequestAttachment_Detail_Feature FOREIGN KEY (DetailID) REFERENCES dbo.TDAPPurchaseRequestDetail(DetailID)
    );
END;
