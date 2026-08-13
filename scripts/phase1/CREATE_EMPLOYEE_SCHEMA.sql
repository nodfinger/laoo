SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADEmployee', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADEmployee
    (
        EmployeeID            bigint IDENTITY(1,1) NOT NULL,
        CompanyID             bigint NOT NULL,
        DivisionOrgUnitID     bigint NULL,
        DepartmentOrgUnitID   bigint NULL,
        EmployeeCode          nvarchar(50) NOT NULL,
        FullName              nvarchar(200) NOT NULL,
        NickName              nvarchar(100) NULL,
        PositionCode          nvarchar(50) NULL,
        Email                 nvarchar(200) NULL,
        Telephone             nvarchar(50) NULL,
        PersonalTelephone     nvarchar(50) NULL,
        StartWorkDate         date NULL,
        ImageData             varbinary(max) NULL,
        ImageContentType      nvarchar(100) NULL,
        IsActive              bit NOT NULL CONSTRAINT DF_TDADEmployee_IsActive DEFAULT (1),
        CreateDate            datetime2(3) NOT NULL CONSTRAINT DF_TDADEmployee_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate            datetime2(3) NULL,
        CONSTRAINT PK_TDADEmployee PRIMARY KEY CLUSTERED (EmployeeID),
        CONSTRAINT FK_TDADEmployee_Company FOREIGN KEY (CompanyID) REFERENCES dbo.TDADCompany(CompanyID),
        CONSTRAINT FK_TDADEmployee_Division FOREIGN KEY (DivisionOrgUnitID) REFERENCES dbo.TDADOrganizationUnit(OrgUnitID),
        CONSTRAINT FK_TDADEmployee_Department FOREIGN KEY (DepartmentOrgUnitID) REFERENCES dbo.TDADOrganizationUnit(OrgUnitID),
        CONSTRAINT CK_TDADEmployee_Code_NotBlank CHECK (LEN(LTRIM(RTRIM(EmployeeCode))) > 0),
        CONSTRAINT CK_TDADEmployee_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(FullName))) > 0)
    );

    CREATE UNIQUE INDEX UX_TDADEmployee_Company_Code
        ON dbo.TDADEmployee(CompanyID, EmployeeCode);

    CREATE INDEX IX_TDADEmployee_Company_Department
        ON dbo.TDADEmployee(CompanyID, DepartmentOrgUnitID, IsActive);
END;

COMMIT TRANSACTION;
