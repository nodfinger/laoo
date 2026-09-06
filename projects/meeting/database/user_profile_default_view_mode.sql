/* Approved migration: user's default list/card display mode. */
IF COL_LENGTH('dbo.TDADUserProfile', 'DefaultViewMode') IS NULL
BEGIN
    ALTER TABLE dbo.TDADUserProfile
        ADD DefaultViewMode NVARCHAR(10) NULL
            CONSTRAINT DF_TDADUserProfile_DefaultViewMode DEFAULT ('LIST') WITH VALUES;
END;

EXEC sys.sp_executesql N'
UPDATE dbo.TDADUserProfile
SET DefaultViewMode = ''LIST''
WHERE DefaultViewMode IS NULL OR UPPER(DefaultViewMode) NOT IN (''LIST'', ''CARD'');';
