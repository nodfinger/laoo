SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADAiChatReview', N'U') IS NULL
    THROW 53901, N'AI chat review table is missing.', 1;

IF COL_LENGTH(N'dbo.TDADAiChatReview', N'AiInterpretationFailed') IS NULL
    ALTER TABLE dbo.TDADAiChatReview ADD AiInterpretationFailed bit NULL;

-- Preserve unprocessed records as unknown; use only recorded outcomes for history.
EXEC(N'UPDATE dbo.TDADAiChatReview
SET AiInterpretationFailed = CASE WHEN DetectedCapability IN (N''unknown'', N''none'', N''denied'', N''unavailable'') THEN 1 ELSE 0 END
WHERE AiInterpretationFailed IS NULL AND DetectedCapability IS NOT NULL AND DetectedCapability <> N''''');
