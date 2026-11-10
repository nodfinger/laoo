SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'EmployeeNameDisplay') IS NULL
    ALTER TABLE dbo.TDSTCompanySetUp ADD EmployeeNameDisplay varchar(10) NOT NULL
        CONSTRAINT DF_TDSTCompanySetUp_EmployeeNameDisplay DEFAULT ('FULL') WITH VALUES;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.TDSTCompanySetUp') AND name = N'CK_TDSTCompanySetUp_EmployeeNameDisplay')
    EXEC(N'ALTER TABLE dbo.TDSTCompanySetUp WITH CHECK ADD CONSTRAINT CK_TDSTCompanySetUp_EmployeeNameDisplay CHECK (EmployeeNameDisplay IN (''FULL'',''NICK'',''BOTH''))');
