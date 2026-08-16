/*
  Password reset token storage.
  The application stores only SHA-256(Token) in TokenHash.
*/
IF OBJECT_ID(N'dbo.TDADPasswordResetToken', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADPasswordResetToken
    (
        PasswordResetTokenID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADPasswordResetToken PRIMARY KEY,
        UserType NVARCHAR(30) NOT NULL,
        SubjectID NVARCHAR(100) NOT NULL,
        ProjectID BIGINT NULL,
        PartnerID BIGINT NULL,
        CompanyID BIGINT NULL,
        Username NVARCHAR(100) NOT NULL,
        Email NVARCHAR(320) NOT NULL,
        TokenHash VARBINARY(32) NOT NULL,
        ExpiresAt DATETIME2(3) NOT NULL,
        UsedAt DATETIME2(3) NULL,
        RequestIP NVARCHAR(64) NULL,
        CreateDate DATETIME2(3) NOT NULL
            CONSTRAINT DF_TDADPasswordResetToken_CreateDate DEFAULT SYSUTCDATETIME()
    );

    CREATE UNIQUE INDEX UX_TDADPasswordResetToken_TokenHash
        ON dbo.TDADPasswordResetToken(TokenHash);

    CREATE INDEX IX_TDADPasswordResetToken_Subject_Active
        ON dbo.TDADPasswordResetToken(SubjectID, ExpiresAt, UsedAt);
END;
GO
