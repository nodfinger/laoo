/* Employee vehicle images: up to two images per employee. */
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADEmployeeCarImage', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADEmployeeCarImage
    (
        EmployeeCarImageID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADEmployeeCarImage PRIMARY KEY,
        EmployeeID BIGINT NOT NULL,
        CarNo TINYINT NOT NULL,
        ImageData VARBINARY(MAX) NOT NULL,
        ContentType NVARCHAR(100) NOT NULL,
        FileName NVARCHAR(250) NULL,
        FileSize INT NOT NULL,
        ImageWidth INT NULL,
        ImageHeight INT NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_TDADEmployeeCarImage_IsActive DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL
            CONSTRAINT DF_TDADEmployeeCarImage_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy BIGINT NULL,
        UpdateDate DATETIME2(3) NULL,
        UpdateBy BIGINT NULL,
        CONSTRAINT FK_TDADEmployeeCarImage_Employee
            FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT CK_TDADEmployeeCarImage_CarNo
            CHECK (CarNo IN (1, 2)),
        CONSTRAINT CK_TDADEmployeeCarImage_FileSize
            CHECK (FileSize BETWEEN 1 AND 102400),
        CONSTRAINT UQ_TDADEmployeeCarImage_EmployeeCar
            UNIQUE (EmployeeID, CarNo)
    );

    CREATE INDEX IX_TDADEmployeeCarImage_EmployeeActive
        ON dbo.TDADEmployeeCarImage(EmployeeID, IsActive, CarNo);
END;

COMMIT TRANSACTION;
GO
