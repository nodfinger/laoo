SET NOCOUNT ON;
SET XACT_ABORT ON;
IF COL_LENGTH(N'dbo.TDADAiChatReview', N'SelectedCapabilitiesJson') IS NULL
    ALTER TABLE dbo.TDADAiChatReview ADD SelectedCapabilitiesJson nvarchar(max) NULL;
IF COL_LENGTH(N'dbo.TDADAiChatReview', N'TestedCapabilitiesJson') IS NULL
    ALTER TABLE dbo.TDADAiChatReview ADD TestedCapabilitiesJson nvarchar(max) NULL;
