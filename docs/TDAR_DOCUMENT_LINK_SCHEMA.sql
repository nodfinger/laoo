/*
    ตารางกลางสำหรับเชื่อมโยงเอกสารของระบบขาย

    ตัวอย่าง DocumentType ที่ระบบใช้:
      QUOTATION       = ใบเสนอราคา
      PREORDER        = ใบรับจองสินค้า
      TEMP_RECEIPT    = ใบเสร็จรับเงินชั่วคราว
      DELIVERY_NOTE   = ใบส่งของ
      TAX_INVOICE     = ใบกำกับภาษี

    ไม่สร้าง Foreign Key ไปยังตารางเอกสารโดยตรง
    เพื่อรองรับการสร้างตารางเอกสารแต่ละประเภทภายหลัง
    และรองรับเอกสารหนึ่งใบที่เชื่อมโยงได้หลายใบ เช่น ส่งของบางส่วน
*/

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDARDocumentLink', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARDocumentLink
    (
        DocumentLinkID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDARDocumentLink PRIMARY KEY,
        CompanyID bigint NOT NULL,
        FromDocumentType nvarchar(30) NOT NULL,
        FromDocumentID bigint NOT NULL,
        ToDocumentType nvarchar(30) NOT NULL,
        ToDocumentID bigint NOT NULL,
        LinkType nvarchar(30) NOT NULL
            CONSTRAINT DF_TDARDocumentLink_LinkType DEFAULT (N'REFERENCE'),
        LinkDescription nvarchar(500) NULL,
        IsActive bit NOT NULL
            CONSTRAINT DF_TDARDocumentLink_IsActive DEFAULT (1),
        CreateDate datetime2(7) NOT NULL
            CONSTRAINT DF_TDARDocumentLink_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,

        CONSTRAINT CK_TDARDocumentLink_SourceTarget
            CHECK
            (
                FromDocumentType <> ToDocumentType
                OR FromDocumentID <> ToDocumentID
            ),
        CONSTRAINT UQ_TDARDocumentLink_Relation
            UNIQUE
            (
                CompanyID,
                FromDocumentType,
                FromDocumentID,
                ToDocumentType,
                ToDocumentID,
                LinkType
            )
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_TDARDocumentLink_FromDocument'
      AND object_id = OBJECT_ID(N'dbo.TDARDocumentLink')
)
BEGIN
    CREATE INDEX IX_TDARDocumentLink_FromDocument
        ON dbo.TDARDocumentLink
        (
            CompanyID,
            FromDocumentType,
            FromDocumentID,
            IsActive
        );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_TDARDocumentLink_ToDocument'
      AND object_id = OBJECT_ID(N'dbo.TDARDocumentLink')
)
BEGIN
    CREATE INDEX IX_TDARDocumentLink_ToDocument
        ON dbo.TDARDocumentLink
        (
            CompanyID,
            ToDocumentType,
            ToDocumentID,
            IsActive
        );
END;

COMMIT TRANSACTION;

SELECT
    name AS TableName,
    create_date AS CreatedDate
FROM sys.tables
WHERE object_id = OBJECT_ID(N'dbo.TDARDocumentLink');

