SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDSVSurvey', N'TargetMode') IS NULL
BEGIN
    ALTER TABLE dbo.TDSVSurvey ADD TargetMode nvarchar(10) NULL;
END;

EXEC(N'UPDATE dbo.TDSVSurvey
SET TargetMode = ReturnReason, ReturnReason = NULL
WHERE TargetMode IS NULL AND ReturnReason IN (N''ALL'', N''CUSTOM'');');

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_TDSVSurvey_TargetMode')
BEGIN
    EXEC(N'ALTER TABLE dbo.TDSVSurvey ADD CONSTRAINT CK_TDSVSurvey_TargetMode
        CHECK (TargetMode IS NULL OR TargetMode IN (N''ALL'', N''CUSTOM''));');
END;
