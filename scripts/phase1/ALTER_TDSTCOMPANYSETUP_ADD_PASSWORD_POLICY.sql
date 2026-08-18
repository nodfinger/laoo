USE [DBTDLaoo];
GO

IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'PasswordPolicyCode') IS NULL
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp
        ADD PasswordPolicyCode tinyint NULL;
END;
GO

UPDATE dbo.TDSTCompanySetUp
SET PasswordPolicyCode = 3
WHERE PasswordPolicyCode IS NULL;

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.TDSTCompanySetUp')
      AND name = N'DF_TDSTCompanySetUp_PasswordPolicyCode'
)
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp
        ADD CONSTRAINT DF_TDSTCompanySetUp_PasswordPolicyCode
        DEFAULT (3) FOR PasswordPolicyCode;
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.TDSTCompanySetUp')
      AND name = N'CK_TDSTCompanySetUp_PasswordPolicyCode'
)
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp
        ADD CONSTRAINT CK_TDSTCompanySetUp_PasswordPolicyCode
        CHECK (PasswordPolicyCode IN (1, 2, 3));
END;
