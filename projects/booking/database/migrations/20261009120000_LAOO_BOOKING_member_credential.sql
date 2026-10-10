SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDBKMemberCredential', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDBKMemberCredential(
        CompanyID bigint NOT NULL,
        MemberID bigint NOT NULL,
        PasswordHash nvarchar(500) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDBKMemberCredential_Active DEFAULT(1),
        MustChangePassword bit NOT NULL CONSTRAINT DF_TDBKMemberCredential_Change DEFAULT(1),
        FailedLoginCount int NOT NULL CONSTRAINT DF_TDBKMemberCredential_Failed DEFAULT(0),
        LockedUntil datetime2 NULL,
        TokenVersion int NOT NULL CONSTRAINT DF_TDBKMemberCredential_Version DEFAULT(1),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_TDBKMemberCredential_Updated DEFAULT(SYSUTCDATETIME()),
        UpdatedBy bigint NULL,
        CONSTRAINT PK_TDBKMemberCredential PRIMARY KEY(CompanyID, MemberID),
        CONSTRAINT FK_TDBKMemberCredential_Member FOREIGN KEY(CompanyID, MemberID)
            REFERENCES dbo.TDBKMember(CompanyID, MemberID),
        CONSTRAINT CK_TDBKMemberCredential_Failed CHECK(FailedLoginCount >= 0),
        CONSTRAINT CK_TDBKMemberCredential_Version CHECK(TokenVersion > 0)
    );
END;
