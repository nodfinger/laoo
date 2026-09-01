USE [DBTDMeeting];
GO

IF OBJECT_ID(N'dbo.TDADOrganizationSupervisor', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADOrganizationSupervisor
    (
        SupervisorID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADOrganizationSupervisor PRIMARY KEY,
        CompanyID bigint NOT NULL,
        OrgUnitID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        SupervisorType nvarchar(30) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADOrganizationSupervisor_IsActive DEFAULT (1),
        CreateDate datetime2 NOT NULL CONSTRAINT DF_TDADOrganizationSupervisor_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2 NULL,
        UpdateBy bigint NULL,
        CONSTRAINT CK_TDADOrganizationSupervisor_Type CHECK (SupervisorType IN (N'DIVISION_MANAGER', N'DEPARTMENT_HEAD')),
        CONSTRAINT UQ_TDADOrganizationSupervisor_UnitType UNIQUE (CompanyID, OrgUnitID, SupervisorType),
        CONSTRAINT FK_TDADOrganizationSupervisor_Unit FOREIGN KEY (OrgUnitID) REFERENCES dbo.TDADOrganizationUnit(OrgUnitID),
        CONSTRAINT FK_TDADOrganizationSupervisor_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID)
    );
END;
GO
