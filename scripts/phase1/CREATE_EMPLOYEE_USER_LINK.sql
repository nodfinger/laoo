USE [DBTDLaoo];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADUserEmployee', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADUserEmployee
    (
        UserEmployeeID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADUserEmployee PRIMARY KEY,
        UserID BIGINT NOT NULL,
        EmployeeID BIGINT NOT NULL,
        CompanyID BIGINT NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDADUserEmployee_IsActive DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL CONSTRAINT DF_TDADUserEmployee_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2(3) NULL,
        CONSTRAINT FK_TDADUserEmployee_User FOREIGN KEY (UserID) REFERENCES dbo.TDADUser(UserID),
        CONSTRAINT FK_TDADUserEmployee_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT UQ_TDADUserEmployee_User UNIQUE (UserID),
        CONSTRAINT UQ_TDADUserEmployee_Employee UNIQUE (EmployeeID)
    );
    CREATE INDEX IX_TDADUserEmployee_Company ON dbo.TDADUserEmployee(CompanyID, IsActive);
END;

IF OBJECT_ID(N'dbo.TDADPartnerUserEmployee', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADPartnerUserEmployee
    (
        PartnerUserEmployeeID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADPartnerUserEmployee PRIMARY KEY,
        PartnerUserID BIGINT NOT NULL,
        EmployeeID BIGINT NOT NULL,
        PartnerID BIGINT NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDADPartnerUserEmployee_IsActive DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL CONSTRAINT DF_TDADPartnerUserEmployee_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2(3) NULL,
        CONSTRAINT FK_TDADPartnerUserEmployee_User FOREIGN KEY (PartnerUserID) REFERENCES dbo.TDADPartnerUser(PartnerUserID),
        CONSTRAINT FK_TDADPartnerUserEmployee_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
        CONSTRAINT UQ_TDADPartnerUserEmployee_User UNIQUE (PartnerUserID),
        CONSTRAINT UQ_TDADPartnerUserEmployee_Employee UNIQUE (EmployeeID)
    );
    CREATE INDEX IX_TDADPartnerUserEmployee_Partner ON dbo.TDADPartnerUserEmployee(PartnerID, IsActive);
END;

COMMIT TRANSACTION;
GO
