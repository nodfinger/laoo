IF COL_LENGTH(N'dbo.TDADUserProfile', N'MenuStyleCode') IS NULL
BEGIN
    ALTER TABLE dbo.TDADUserProfile
        ADD MenuStyleCode NVARCHAR(10) NULL;
END;

UPDATE dbo.TDADUserProfile
SET MenuStyleCode = 'SLIDE'
WHERE MenuStyleCode IS NULL;

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.TDADUserProfile')
      AND name = N'DF_TDADUserProfile_MenuStyleCode'
)
BEGIN
    ALTER TABLE dbo.TDADUserProfile
        ADD CONSTRAINT DF_TDADUserProfile_MenuStyleCode
        DEFAULT 'SLIDE' FOR MenuStyleCode;
END;

ALTER TABLE dbo.TDADUserProfile
    ALTER COLUMN MenuStyleCode NVARCHAR(10) NOT NULL;

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.TDADUserProfile')
      AND name = N'CK_TDADUserProfile_MenuStyleCode'
)
BEGIN
    ALTER TABLE dbo.TDADUserProfile
        ADD CONSTRAINT CK_TDADUserProfile_MenuStyleCode
        CHECK (MenuStyleCode IN ('SLIDE', 'BUTTON'));
END;
