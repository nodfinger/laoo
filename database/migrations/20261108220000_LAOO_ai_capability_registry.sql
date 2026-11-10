SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADMainMenu', N'U') IS NULL OR OBJECT_ID(N'dbo.TDSTCompanySetUp', N'U') IS NULL
    THROW 53901, N'Required menu or company table is missing.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10008' AND
    (MenuGroupCode<>N'10' OR ScreenType<>1 OR RoutePath<>N'/company/ai-capabilities'))
    THROW 53902, N'Menu 10008 is already assigned to another screen.', 1;

IF OBJECT_ID(N'dbo.TDADAiCapability', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADAiCapability
    (
        CapabilityCode nvarchar(100) NOT NULL CONSTRAINT PK_TDADAiCapability PRIMARY KEY,
        NameTH nvarchar(200) NOT NULL,
        DescriptionTH nvarchar(1000) NOT NULL,
        ProjectCode nvarchar(50) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADAiCapability_IsActive DEFAULT (1),
        CreateDate datetime2 NOT NULL CONSTRAINT DF_TDADAiCapability_CreateDate DEFAULT (SYSUTCDATETIME())
    );
END;
IF OBJECT_ID(N'dbo.TDADAiCapabilityCompany', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADAiCapabilityCompany
    (
        CompanyID bigint NOT NULL,
        CapabilityCode nvarchar(100) NOT NULL,
        IsEnabled bit NOT NULL CONSTRAINT DF_TDADAiCapabilityCompany_Enabled DEFAULT (0),
        DisplayName nvarchar(200) NULL,
        DescriptionTH nvarchar(1000) NULL,
        ExamplesJson nvarchar(max) NULL,
        AllowPdf bit NOT NULL CONSTRAINT DF_TDADAiCapabilityCompany_Pdf DEFAULT (0),
        AllowPng bit NOT NULL CONSTRAINT DF_TDADAiCapabilityCompany_Png DEFAULT (0),
        AllowHtml bit NOT NULL CONSTRAINT DF_TDADAiCapabilityCompany_Html DEFAULT (0),
        AllowEmail bit NOT NULL CONSTRAINT DF_TDADAiCapabilityCompany_Email DEFAULT (0),
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_TDADAiCapabilityCompany_UpdateDate DEFAULT (SYSUTCDATETIME()),
        UpdateBy bigint NULL,
        CONSTRAINT PK_TDADAiCapabilityCompany PRIMARY KEY (CompanyID, CapabilityCode),
        CONSTRAINT FK_TDADAiCapabilityCompany_Capability FOREIGN KEY (CapabilityCode) REFERENCES dbo.TDADAiCapability(CapabilityCode),
        CONSTRAINT CK_TDADAiCapabilityCompany_Examples CHECK (ExamplesJson IS NULL OR ISJSON(ExamplesJson)=1)
    );
END;

-- Do not overwrite labels or any existing Company setting on reinstallation.
INSERT dbo.TDADAiCapability(CapabilityCode,NameTH,DescriptionTH,ProjectCode)
SELECT v.Code,v.NameTH,v.DescriptionTH,N'LAOO_SERVICE'
FROM (VALUES
 (N'repair.track_own',N'ติดตามงานซ่อมของฉัน',N'แสดงสถานะงานซ่อมที่ผู้ใช้สร้าง'),
 (N'repair.parts_cost',N'สรุปต้นทุนอะไหล่งานซ่อม',N'สรุปต้นทุนอะไหล่ของงานที่เสร็จตามช่วงวันที่'),
 (N'repair.create_own',N'แจ้งงานซ่อมใหม่',N'สร้างใบแจ้งซ่อมหลังผู้ใช้ยืนยัน')
) v(Code,NameTH,DescriptionTH)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapability x WHERE x.CapabilityCode=v.Code);

-- Existing chat users retain the already implemented tracking feature only.
INSERT dbo.TDADAiCapabilityCompany(CompanyID,CapabilityCode,IsEnabled)
SELECT C.CompanyID,N'repair.track_own',1
FROM dbo.TDSTCompanySetUp C
WHERE C.OwnerType=N'C' AND C.IsActive=1 AND C.AiChatEnabled=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapabilityCompany X WHERE X.CompanyID=C.CompanyID AND X.CapabilityCode=N'repair.track_own');

DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @ProjectID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=N'05' AND IsActive=1)
    THROW 53903, N'Core project or settings menu group is unavailable.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'10008')
 INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate)
 VALUES(N'10008',N'10',N'จัดการความสามารถ AI',1,N'companyAiCapabilities',N'/company/ai-capabilities',N'smart_toy',80,1,1,1,SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode=N'10008')
 INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
 VALUES(@ProjectID,N'10008',N'05',80,1,SYSUTCDATETIME());
