/*
  Employee images: one FORMAL image and one PROFILE image per employee.
  Review and approve before execution.
*/
IF OBJECT_ID(N'dbo.TDADEmployeeImage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADEmployeeImage
    (
        EmployeeImageID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADEmployeeImage PRIMARY KEY,
        EmployeeID BIGINT NOT NULL,
        ImageType NVARCHAR(20) NOT NULL,
        ImageData VARBINARY(MAX) NOT NULL,
        ContentType NVARCHAR(100) NOT NULL,
        FileName NVARCHAR(250) NULL,
        FileSize INT NOT NULL,
        ImageWidth INT NULL,
        ImageHeight INT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDADEmployeeImage_IsActive DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL CONSTRAINT DF_TDADEmployeeImage_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy BIGINT NULL,
        UpdateDate DATETIME2(3) NULL,
        UpdateBy BIGINT NULL,
        CONSTRAINT FK_TDADEmployeeImage_Employee
            FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT CK_TDADEmployeeImage_ImageType
            CHECK (ImageType IN (N'FORMAL', N'PROFILE')),
        CONSTRAINT CK_TDADEmployeeImage_FileSize
            CHECK (FileSize BETWEEN 1 AND 102400),
        CONSTRAINT UQ_TDADEmployeeImage_EmployeeType
            UNIQUE (EmployeeID, ImageType)
    );

    CREATE INDEX IX_TDADEmployeeImage_EmployeeActive
        ON dbo.TDADEmployeeImage(EmployeeID, IsActive, ImageType);
END;
GO

/* Metadata LastUpdate is intentionally not inserted automatically. */
