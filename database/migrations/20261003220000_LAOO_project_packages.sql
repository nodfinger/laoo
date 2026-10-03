SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADProjectPackage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADProjectPackage
    (
        PackageID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADProjectPackage PRIMARY KEY,
        ProjectID bigint NOT NULL,
        PackageCode nvarchar(50) NOT NULL,
        PackageNameTH nvarchar(200) NOT NULL,
        PackageNameEN nvarchar(200) NULL,
        TierCode nvarchar(30) NOT NULL,
        BillingCycle nvarchar(20) NOT NULL CONSTRAINT DF_TDADProjectPackage_BillingCycle DEFAULT N'MONTHLY',
        Price decimal(18,2) NOT NULL CONSTRAINT DF_TDADProjectPackage_Price DEFAULT 0,
        CurrencyCode char(3) NOT NULL CONSTRAINT DF_TDADProjectPackage_Currency DEFAULT 'THB',
        TrialDays int NOT NULL CONSTRAINT DF_TDADProjectPackage_TrialDays DEFAULT 0,
        SortOrder int NOT NULL CONSTRAINT DF_TDADProjectPackage_SortOrder DEFAULT 0,
        IsActive bit NOT NULL CONSTRAINT DF_TDADProjectPackage_IsActive DEFAULT 1,
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDADProjectPackage_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        UpdateDate datetime2(7) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADProjectPackage_Project_Code UNIQUE(ProjectID, PackageCode),
        CONSTRAINT FK_TDADProjectPackage_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT CK_TDADProjectPackage_Billing CHECK(BillingCycle IN(N'NONE',N'MONTHLY',N'YEARLY')),
        CONSTRAINT CK_TDADProjectPackage_Tier CHECK(TierCode IN(N'FREE',N'STANDARD',N'ENTERPRISE')),
        CONSTRAINT CK_TDADProjectPackage_Value CHECK(Price>=0 AND TrialDays>=0)
    );
    CREATE INDEX IX_TDADProjectPackage_Project_Active ON dbo.TDADProjectPackage(ProjectID,IsActive,SortOrder);
END;

IF OBJECT_ID(N'dbo.TDADProjectPackageFeature', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADProjectPackageFeature
    (
        PackageFeatureID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADProjectPackageFeature PRIMARY KEY,
        PackageID bigint NOT NULL,
        FeatureCode nvarchar(50) NOT NULL,
        IsEnabled bit NOT NULL CONSTRAINT DF_TDADProjectPackageFeature_IsEnabled DEFAULT 1,
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDADProjectPackageFeature_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        CONSTRAINT UQ_TDADProjectPackageFeature UNIQUE(PackageID,FeatureCode),
        CONSTRAINT FK_TDADProjectPackageFeature_Package FOREIGN KEY(PackageID) REFERENCES dbo.TDADProjectPackage(PackageID)
    );
END;

IF OBJECT_ID(N'dbo.TDADProjectPackageQuota', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADProjectPackageQuota
    (
        PackageQuotaID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADProjectPackageQuota PRIMARY KEY,
        PackageID bigint NOT NULL,
        QuotaCode nvarchar(50) NOT NULL,
        QuotaNameTH nvarchar(200) NOT NULL,
        LimitValue decimal(18,2) NOT NULL,
        UnitCode nvarchar(30) NOT NULL,
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDADProjectPackageQuota_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        CONSTRAINT UQ_TDADProjectPackageQuota UNIQUE(PackageID,QuotaCode),
        CONSTRAINT FK_TDADProjectPackageQuota_Package FOREIGN KEY(PackageID) REFERENCES dbo.TDADProjectPackage(PackageID),
        CONSTRAINT CK_TDADProjectPackageQuota_Value CHECK(LimitValue>=-1)
    );
END;

IF OBJECT_ID(N'dbo.TDADCompanyProjectSubscription', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADCompanyProjectSubscription
    (
        SubscriptionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADCompanyProjectSubscription PRIMARY KEY,
        PartnerID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        ProjectID bigint NOT NULL,
        PackageID bigint NOT NULL,
        StatusCode nvarchar(20) NOT NULL,
        StartDate date NOT NULL,
        ExpireDate date NULL,
        IsCurrent bit NOT NULL CONSTRAINT DF_TDADCompanyProjectSubscription_IsCurrent DEFAULT 1,
        ReasonText nvarchar(500) NULL,
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDADCompanyProjectSubscription_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NULL,
        UpdateDate datetime2(7) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDADCompanyProjectSubscription_Partner FOREIGN KEY(PartnerID) REFERENCES dbo.TDADPartner(PartnerID),
        CONSTRAINT FK_TDADCompanyProjectSubscription_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT FK_TDADCompanyProjectSubscription_Package FOREIGN KEY(PackageID) REFERENCES dbo.TDADProjectPackage(PackageID),
        CONSTRAINT CK_TDADCompanyProjectSubscription_Status CHECK(StatusCode IN(N'TRIAL',N'ACTIVE',N'EXPIRED',N'SUSPENDED',N'CANCELLED')),
        CONSTRAINT CK_TDADCompanyProjectSubscription_Date CHECK(ExpireDate IS NULL OR ExpireDate>=StartDate)
    );
    CREATE UNIQUE INDEX UX_TDADCompanyProjectSubscription_Current
      ON dbo.TDADCompanyProjectSubscription(CompanyID,ProjectID) WHERE IsCurrent=1;
    CREATE INDEX IX_TDADCompanyProjectSubscription_PartnerCompany
      ON dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,IsCurrent,StatusCode);
END;

IF OBJECT_ID(N'dbo.TDADCompanyProjectSubscriptionAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADCompanyProjectSubscriptionAudit
    (
        AuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADCompanyProjectSubscriptionAudit PRIMARY KEY,
        SubscriptionID bigint NULL,
        PartnerID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        ProjectID bigint NOT NULL,
        PackageID bigint NULL,
        ActionCode nvarchar(30) NOT NULL,
        BeforeJson nvarchar(max) NULL,
        AfterJson nvarchar(max) NULL,
        ReasonText nvarchar(500) NULL,
        ActorType nvarchar(30) NOT NULL,
        ActorID bigint NULL,
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDADCompanyProjectSubscriptionAudit_CreateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_TDADCompanyProjectSubscriptionAudit_Action CHECK(ActionCode IN(N'ASSIGN',N'RENEW',N'UPGRADE',N'DOWNGRADE',N'SUSPEND',N'CANCEL',N'EXPIRE'))
    );
    CREATE INDEX IX_TDADCompanyProjectSubscriptionAudit_Target
      ON dbo.TDADCompanyProjectSubscriptionAudit(CompanyID,ProjectID,CreateDate DESC);
END;

DECLARE @Packages TABLE(TierCode nvarchar(30),PackageCode nvarchar(50),PackageNameTH nvarchar(200),BillingCycle nvarchar(20),SortOrder int);
INSERT @Packages VALUES
 (N'FREE',N'FREE',N'ฟรี',N'NONE',10),
 (N'STANDARD',N'STANDARD',N'มาตรฐาน',N'MONTHLY',20),
 (N'ENTERPRISE',N'ENTERPRISE',N'องค์กร',N'YEARLY',30);

INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,TierCode,BillingCycle,SortOrder,IsActive)
SELECT P.ProjectID,X.PackageCode,X.PackageNameTH,X.TierCode,X.BillingCycle,X.SortOrder,1
FROM dbo.TDADProject P CROSS JOIN @Packages X
WHERE P.IsActive=1 AND P.ProjectType<>N'CORE'
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADProjectPackage T WHERE T.ProjectID=P.ProjectID AND T.PackageCode=X.PackageCode);

INSERT dbo.TDADProjectPackageQuota(PackageID,QuotaCode,QuotaNameTH,LimitValue,UnitCode)
SELECT PK.PackageID,Q.QuotaCode,Q.QuotaNameTH,
       CASE PK.TierCode WHEN N'FREE' THEN Q.FreeLimit WHEN N'STANDARD' THEN Q.StandardLimit ELSE Q.EnterpriseLimit END,
       Q.UnitCode
FROM dbo.TDADProjectPackage PK
CROSS APPLY(VALUES
 (N'MAX_USERS',N'จำนวนผู้ใช้',CAST(5 AS decimal(18,2)),CAST(25 AS decimal(18,2)),CAST(-1 AS decimal(18,2)),N'USER'),
 (N'MAX_BRANCHES',N'จำนวนสาขา',1,3,-1,N'BRANCH'),
 (N'STORAGE_MB',N'พื้นที่จัดเก็บไฟล์',1024,5120,51200,N'MB')
) Q(QuotaCode,QuotaNameTH,FreeLimit,StandardLimit,EnterpriseLimit,UnitCode)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectPackageQuota T WHERE T.PackageID=PK.PackageID AND T.QuotaCode=Q.QuotaCode);

INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled)
SELECT DISTINCT PK.PackageID,M.FeatureCode,1
FROM dbo.TDADProjectPackage PK
JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=PK.ProjectID AND PM.IsActive=1
JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1 AND M.FeatureCode IS NOT NULL
WHERE PK.TierCode IN(N'STANDARD',N'ENTERPRISE')
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=PK.PackageID AND F.FeatureCode=M.FeatureCode);

INSERT dbo.TDADCompanyProjectSubscription
 (PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText,CreateDate,CreateBy)
SELECT CP.PartnerID,CP.CompanyID,CP.ProjectID,PK.PackageID,
       CASE WHEN CP.IsEnabled=0 THEN N'SUSPENDED' WHEN CP.IsTrial=1 THEN N'TRIAL' ELSE N'ACTIVE' END,
       COALESCE(CP.StartDate,CONVERT(date,CP.CreateDate),CONVERT(date,SYSUTCDATETIME())),CP.ExpireDate,1,N'Migrated from TDADCompanyProject',SYSUTCDATETIME(),CP.CreatedBy
FROM dbo.TDADCompanyProject CP
JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID AND P.ProjectType<>N'CORE'
JOIN dbo.TDADProjectPackage PK ON PK.ProjectID=CP.ProjectID AND PK.PackageCode=CASE WHEN P.ProjectCode=N'LAOO_PROVIDER' THEN N'FREE' ELSE N'STANDARD' END
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription S WHERE S.CompanyID=CP.CompanyID AND S.ProjectID=CP.ProjectID AND S.IsCurrent=1);

COMMIT TRANSACTION;
