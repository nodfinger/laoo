/*
  Master name of employee-level permission points.
  One MenuCode can have many PermissionPointCode values.
*/
IF OBJECT_ID(N'dbo.TDADUserPermissionPointName', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADUserPermissionPointName
    (
        PermissionPointNameID BIGINT IDENTITY(1,1) NOT NULL,
        MenuCode NVARCHAR(20) NOT NULL,
        PermissionPointCode NVARCHAR(80) NOT NULL,
        PermissionPointName NVARCHAR(200) NOT NULL,
        PermissionPointDescription NVARCHAR(500) NULL,
        SortOrder INT NOT NULL
            CONSTRAINT DF_TDADUserPermissionPointName_SortOrder DEFAULT (0),
        IsActive BIT NOT NULL
            CONSTRAINT DF_TDADUserPermissionPointName_IsActive DEFAULT (1),
        CreatedBy BIGINT NULL,
        CreatedDate DATETIME2(7) NOT NULL
            CONSTRAINT DF_TDADUserPermissionPointName_CreatedDate DEFAULT (SYSUTCDATETIME()),
        UpdatedBy BIGINT NULL,
        UpdatedDate DATETIME2(7) NULL,

        CONSTRAINT PK_TDADUserPermissionPointName
            PRIMARY KEY (PermissionPointNameID),
        CONSTRAINT UQ_TDADUserPermissionPointName_MenuCodePointCode
            UNIQUE (MenuCode, PermissionPointCode)
        /*
          ไม่สร้าง Foreign Key ตรงนี้ เพราะชนิดข้อมูล MenuCode ของ
          TDADMainMenu ในฐานข้อมูลเดิมไม่ตรงกันทุก environment
          ระบบจะตรวจ MenuCode ด้วยการ join กับ TDADMainMenu ตอนอ่านข้อมูล
        */
    );
END;
GO

IF OBJECT_ID(N'dbo.TDADUserPermissionPointName', N'U') IS NOT NULL
AND NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADUserPermissionPointName')
      AND name = N'IX_TDADUserPermissionPointName_MenuCode'
)
BEGIN
    CREATE INDEX IX_TDADUserPermissionPointName_MenuCode
        ON dbo.TDADUserPermissionPointName(MenuCode, IsActive, SortOrder);
END;
GO

/* ตัวอย่างข้อมูล
INSERT dbo.TDADUserPermissionPointName
    (MenuCode, PermissionPointCode, PermissionPointName, SortOrder)
VALUES
    (N'09001', N'CUSTOMER_BUSINESS_CARD', N'ปุ่มนามบัตร', 1),
    (N'09001', N'CUSTOMER_DOCUMENT', N'ปุ่มเอกสารลูกค้า', 2);
*/
