IF OBJECT_ID(N'dbo.TDARCustomerFile', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDARCustomerFile
    (
        CustomerFileID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDARCustomerFile PRIMARY KEY,
        CompanyID BIGINT NOT NULL,
        CustomerID BIGINT NOT NULL,
        FileType NVARCHAR(30) NOT NULL,
        OriginalFileName NVARCHAR(255) NOT NULL,
        StoredFileName NVARCHAR(255) NOT NULL,
        RelativePath NVARCHAR(500) NOT NULL,
        Extension NVARCHAR(20) NOT NULL,
        ContentType NVARCHAR(100) NULL,
        FileSize BIGINT NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDARCustomerFile_IsActive DEFAULT (1),
        CreateBy BIGINT NULL,
        CreateDate DATETIME2(7) NOT NULL CONSTRAINT DF_TDARCustomerFile_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2(7) NULL,
        CONSTRAINT CK_TDARCustomerFile_FileType CHECK (FileType IN (N'BUSINESS_CARD', N'CUSTOMER_DOCUMENT'))
    );

    CREATE INDEX IX_TDARCustomerFile_Scope
        ON dbo.TDARCustomerFile(CompanyID, CustomerID, FileType, IsActive);
END;
GO

IF OBJECT_ID(N'dbo.TDARCustomerFile', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.TDARCustomerFile', N'Description') IS NULL
BEGIN
    ALTER TABLE dbo.TDARCustomerFile ADD Description NVARCHAR(1000) NULL;
END;
GO

-- TDARCustomer.CustomerID ไม่มี Primary/Unique Key ในฐานข้อมูลชุดนี้
-- API จึงตรวจ CompanyID + CustomerID ก่อนเข้าถึงไฟล์แทน Foreign Key
