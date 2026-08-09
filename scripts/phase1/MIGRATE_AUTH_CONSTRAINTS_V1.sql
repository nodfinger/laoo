USE [DBTDLaoo]
GO

SET XACT_ABORT ON
GO

IF EXISTS
(
    SELECT NormalizedUsername
    FROM dbo.TDADLaooUser
    GROUP BY NormalizedUsername
    HAVING COUNT_BIG(*) > 1
)
    THROW 51001, 'พบ Laoo Support Username ซ้ำ กรุณาแก้ข้อมูลก่อนรัน Migration', 1;
GO

IF EXISTS
(
    SELECT NormalizedUsername
    FROM dbo.TDADUser
    GROUP BY NormalizedUsername
    HAVING COUNT_BIG(*) > 1
)
    THROW 51002, 'พบ Company Username ซ้ำ กรุณาแก้ข้อมูลก่อนรัน Migration', 1;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.TDADPermission AS x
    LEFT JOIN dbo.TDADProject AS p ON p.ProjectID = x.ProjectID
    WHERE p.ProjectID IS NULL
)
    THROW 51003, 'พบ Permission อ้าง Project ที่ไม่มีอยู่', 1;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.TDADPermissionTemplate AS x
    LEFT JOIN dbo.TDADProject AS p ON p.ProjectID = x.ProjectID
    WHERE p.ProjectID IS NULL
)
    THROW 51004, 'พบ Permission Template อ้าง Project ที่ไม่มีอยู่', 1;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.TDADUserPermission AS x
    LEFT JOIN dbo.TDADUser AS u ON u.UserID = x.UserID
    WHERE u.UserID IS NULL
)
    THROW 51005, 'พบ User Permission อ้าง User ที่ไม่มีอยู่', 1;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.TDADUserPermission AS x
    LEFT JOIN dbo.TDADProject AS p ON p.ProjectID = x.ProjectID
    WHERE p.ProjectID IS NULL
)
    THROW 51006, 'พบ User Permission อ้าง Project ที่ไม่มีอยู่', 1;
GO

BEGIN TRANSACTION

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.TDADLaooUser') AND name = N'UX_TDADLaooUser_NormalizedUsername')
    CREATE UNIQUE INDEX UX_TDADLaooUser_NormalizedUsername ON dbo.TDADLaooUser(NormalizedUsername);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.TDADUser') AND name = N'UX_TDADUser_NormalizedUsername')
    CREATE UNIQUE INDEX UX_TDADUser_NormalizedUsername ON dbo.TDADUser(NormalizedUsername);

IF OBJECT_ID(N'dbo.FK_TDADPermission_Project', N'F') IS NULL
    ALTER TABLE dbo.TDADPermission WITH CHECK ADD CONSTRAINT FK_TDADPermission_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID);

IF OBJECT_ID(N'dbo.FK_TDADPermissionTemplate_Project', N'F') IS NULL
    ALTER TABLE dbo.TDADPermissionTemplate WITH CHECK ADD CONSTRAINT FK_TDADPermissionTemplate_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID);

IF OBJECT_ID(N'dbo.FK_TDADUserPermission_Project', N'F') IS NULL
    ALTER TABLE dbo.TDADUserPermission WITH CHECK ADD CONSTRAINT FK_TDADUserPermission_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID);

IF OBJECT_ID(N'dbo.FK_TDADUserPermission_User', N'F') IS NULL
    ALTER TABLE dbo.TDADUserPermission WITH CHECK ADD CONSTRAINT FK_TDADUserPermission_User FOREIGN KEY(UserID) REFERENCES dbo.TDADUser(UserID);

COMMIT TRANSACTION
GO
