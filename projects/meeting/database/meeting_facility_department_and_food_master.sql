USE [DBTDMeeting];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDADMeetingFacility', N'ResponsibleDepartmentOrgUnitID') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingFacility
        ADD ResponsibleDepartmentOrgUnitID BIGINT NULL;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'dbo.TDADMeetingFacility')
      AND name = N'FK_TDADMeetingFacility_ResponsibleDepartment'
)
BEGIN
    ALTER TABLE dbo.TDADMeetingFacility WITH CHECK
        ADD CONSTRAINT FK_TDADMeetingFacility_ResponsibleDepartment
            FOREIGN KEY (ResponsibleDepartmentOrgUnitID)
            REFERENCES dbo.TDADOrganizationUnit (OrgUnitID);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingFacility')
      AND name = N'IX_TDADMeetingFacility_ResponsibleDepartment'
)
BEGIN
    CREATE INDEX IX_TDADMeetingFacility_ResponsibleDepartment
        ON dbo.TDADMeetingFacility (CompanyID, ResponsibleDepartmentOrgUnitID);
END;

IF OBJECT_ID(N'dbo.TDADMeetingFood', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingFood
    (
        FoodID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingFood PRIMARY KEY,
        CompanyID BIGINT NOT NULL,
        FoodCode NVARCHAR(50) NOT NULL,
        FoodNameTH NVARCHAR(200) NOT NULL,
        FoodTypeCode NVARCHAR(20) NOT NULL,
        FoodImageUrl NVARCHAR(500) NULL,
        CreateDate DATETIME2 NOT NULL
            CONSTRAINT DF_TDADMeetingFood_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2 NULL
    );

    CREATE UNIQUE INDEX UX_TDADMeetingFood_Company_Code
        ON dbo.TDADMeetingFood (CompanyID, FoodCode);

    CREATE INDEX IX_TDADMeetingFood_Company_Type
        ON dbo.TDADMeetingFood (CompanyID, FoodTypeCode);
END;

IF COL_LENGTH(N'dbo.TDADMeetingFood', N'FoodImageUrl') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingFood
        ADD FoodImageUrl NVARCHAR(500) NULL;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code = N'011')
BEGIN
    INSERT dbo.TDSTMasterGroup (Code, Name)
    VALUES (N'011', N'ประเภทอาหาร');
END;

DECLARE @FoodTypes TABLE
(
    MasterCode NVARCHAR(20) NOT NULL,
    Name NVARCHAR(500) NOT NULL,
    Seq INT NOT NULL
);

INSERT @FoodTypes (MasterCode, Name, Seq)
VALUES
    (N'00001', N'ข้าว', 1),
    (N'00002', N'เส้น', 2),
    (N'00003', N'ขนม', 3),
    (N'00004', N'เครื่องดื่ม', 4),
    (N'00005', N'อื่น ๆ', 5);

INSERT dbo.TDSTMaster
(
    OwnerType, OwnerPartnerID, OwnerCompanyID, MasterGroupCode, MasterCode,
    Name, Seq, OrderBy, ShortCode, IsActive, CreateDate
)
SELECT
    'L', NULL, NULL, N'011', F.MasterCode,
    F.Name, F.Seq, N'Seq', NULL, 1, SYSUTCDATETIME()
FROM @FoodTypes AS F
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDSTMaster AS M
    WHERE M.OwnerType = 'L'
      AND M.MasterGroupCode = N'011'
      AND M.MasterCode = F.MasterCode
);

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = '15004')
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuGroupCode, MenuCode, MenuName, RouteName, RoutePath, FeatureCode,
        IconName, SortOrder, ScreenType, IsActive, IsVisible, IsFavoriteAllowed,
        CreateDate
    )
    VALUES
    (
        '15', '15004', N'รายการอาหาร', N'meetingFoods',
        N'/company/meeting-foods', N'MEETING_FOOD', N'restaurant_menu',
        30, 1, 1, 1, 1, SYSDATETIME()
    );
END;

COMMIT TRANSACTION;
GO
