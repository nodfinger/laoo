SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADAiUserCommand', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADAiUserCommand (
        CommandID bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CompanyID bigint NOT NULL,
        UserID bigint NOT NULL,
        CommandHash binary(32) NOT NULL,
        CommandText nvarchar(1000) NOT NULL,
        IsFavorite bit NOT NULL CONSTRAINT DF_AiUserCommand_Favorite DEFAULT 0,
        LastUsedAt datetime2 NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_AiUserCommand_Created DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_AiUserCommand_OwnerHash UNIQUE (CompanyID,UserID,CommandHash)
    );
    CREATE INDEX IX_AiUserCommand_OwnerRecent ON dbo.TDADAiUserCommand(CompanyID,UserID,LastUsedAt DESC);
END;
