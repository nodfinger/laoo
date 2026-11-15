IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.TDGPPurpose') AND name=N'ReturnDays' AND is_nullable=0)
BEGIN
    IF OBJECT_ID(N'dbo.CK_TDGPPurpose_ReturnDays',N'C') IS NOT NULL
        ALTER TABLE dbo.TDGPPurpose DROP CONSTRAINT CK_TDGPPurpose_ReturnDays;
    ALTER TABLE dbo.TDGPPurpose ALTER COLUMN ReturnDays int NULL;
END;
IF OBJECT_ID(N'dbo.CK_TDGPPurpose_ReturnDays',N'C') IS NULL
    ALTER TABLE dbo.TDGPPurpose ADD CONSTRAINT CK_TDGPPurpose_ReturnDays CHECK (ReturnDays IS NULL OR ReturnDays BETWEEN 1 AND 365);
IF OBJECT_ID(N'dbo.CK_TDGPPurpose_RequiredReturnDays',N'C') IS NULL
    ALTER TABLE dbo.TDGPPurpose ADD CONSTRAINT CK_TDGPPurpose_RequiredReturnDays CHECK (AlwaysReturnRequired=0 OR ReturnDays IS NOT NULL);
