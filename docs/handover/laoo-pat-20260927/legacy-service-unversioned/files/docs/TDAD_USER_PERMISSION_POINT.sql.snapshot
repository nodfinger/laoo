/*
  Employee-level permission points.
  ใช้กำหนดสิทธิ์ระดับคำสั่ง/ปุ่มภายในหน้าจอ เช่น
    CUSTOMER_BUSINESS_CARD  = ปุ่มนามบัตร
    CUSTOMER_DOCUMENT       = ปุ่มเอกสารลูกค้า

  สิทธิ์เมนูหลักยังคงอ่านจาก TDADRoleGroupPermission ตามเดิม
  ตารางนี้ใช้เสริมเฉพาะปุ่มหรือคำสั่งย่อยภายใน MenuCode นั้น ๆ
*/
IF OBJECT_ID(N'dbo.TDADUserPermissionPoint', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADUserPermissionPoint
    (
        PermissionPointID BIGINT IDENTITY(1,1) NOT NULL,
        ProjectID BIGINT NOT NULL,
        PartnerID BIGINT NULL,
        CompanyID BIGINT NULL,
        EmployeeID BIGINT NOT NULL,
        MenuCode NVARCHAR(20) NOT NULL,
        PermissionPointCode NVARCHAR(80) NOT NULL,
        IsAllowed BIT NOT NULL
            CONSTRAINT DF_TDADUserPermissionPoint_IsAllowed DEFAULT (1),
        IsActive BIT NOT NULL
            CONSTRAINT DF_TDADUserPermissionPoint_IsActive DEFAULT (1),
        EffectiveFrom DATE NULL,
        EffectiveTo DATE NULL,
        CreatedBy BIGINT NULL,
        CreatedDate DATETIME2(7) NOT NULL
            CONSTRAINT DF_TDADUserPermissionPoint_CreatedDate DEFAULT (SYSUTCDATETIME()),
        UpdatedBy BIGINT NULL,
        UpdatedDate DATETIME2(7) NULL,

        CONSTRAINT PK_TDADUserPermissionPoint
            PRIMARY KEY (PermissionPointID),
        CONSTRAINT UQ_TDADUserPermissionPoint_EmployeeMenuPoint
            UNIQUE (ProjectID, EmployeeID, MenuCode, PermissionPointCode),
        CONSTRAINT CK_TDADUserPermissionPoint_EffectiveDate
            CHECK (EffectiveTo IS NULL OR EffectiveFrom IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT FK_TDADUserPermissionPoint_Project
            FOREIGN KEY (ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT FK_TDADUserPermissionPoint_Employee
            FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID)
    );
END;
GO

/* เพิ่มดัชนีสำหรับตรวจสิทธิ์ปุ่มอย่างรวดเร็ว */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADUserPermissionPoint')
      AND name = N'IX_TDADUserPermissionPoint_Lookup'
)
BEGIN
    CREATE INDEX IX_TDADUserPermissionPoint_Lookup
        ON dbo.TDADUserPermissionPoint
        (ProjectID, EmployeeID, MenuCode, PermissionPointCode, IsActive, IsAllowed)
        INCLUDE (PartnerID, CompanyID, EffectiveFrom, EffectiveTo);
END;
GO

/* ตัวอย่างรหัส PermissionPointCode ที่ใช้ในระบบ
   CUSTOMER_BUSINESS_CARD = ปุ่มนามบัตร
   CUSTOMER_DOCUMENT      = ปุ่มเอกสารลูกค้า

   ชื่อสิทธิ์ให้อ่านจาก dbo.TDADUserPermissionPointName
   โดย join ด้วย MenuCode + PermissionPointCode
*/
