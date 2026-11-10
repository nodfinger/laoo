SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Core bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @Core IS NULL THROW 53921, N'Core project is unavailable.', 1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'05004')
    THROW 53922, N'Menu 05004 is already in use.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09003' AND ScreenType=4 AND IsActive=1)
    THROW 53923, N'Quotation menu is unavailable.', 1;
IF OBJECT_ID(N'dbo.TDADDocumentNumberFormat',N'U') IS NOT NULL
    THROW 53924, N'Document format table already exists.', 1;

CREATE TABLE dbo.TDADDocumentNumberFormat (
    CompanyID bigint NOT NULL,
    MenuCode nvarchar(20) NOT NULL,
    Prefix nvarchar(12) NOT NULL,
    DateFormat varchar(8) NOT NULL,
    Digits int NOT NULL,
    UpdateDate datetime2 NOT NULL CONSTRAINT DF_TDADDocumentNumberFormat_UpdateDate DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_TDADDocumentNumberFormat PRIMARY KEY (CompanyID, MenuCode),
    CONSTRAINT CK_TDADDocumentNumberFormat_DateFormat CHECK (DateFormat IN ('NONE','yyyy','yyyyMM','yyyyMMdd')),
    CONSTRAINT CK_TDADDocumentNumberFormat_Digits CHECK (Digits BETWEEN 1 AND 9)
);
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate)
VALUES(N'05004',N'05',N'รูปแบบลำดับข้อมูล',2,N'companyDocumentNumberFormat',N'/company/document-number-format',N'settings',40,1,1,1,SYSUTCDATETIME());
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@Core,N'05004',N'05',40,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
VALUES(@Core,N'05004',N'รูปแบบลำดับข้อมูล',N'Document numbering format',N'VIEW',N'ดูข้อมูล',N'View',1),
      (@Core,N'05004',N'รูปแบบลำดับข้อมูล',N'Document numbering format',N'EDIT',N'แก้ไข',N'Edit',1);
UPDATE dbo.TDADMainMenu SET RunData=1 WHERE MenuCode=N'09003' AND ScreenType=4;
