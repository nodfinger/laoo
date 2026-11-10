IF OBJECT_ID(N'dbo.TDADUserListDisplayPreference', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADUserListDisplayPreference
    (
        UserType char(1) NOT NULL,
        UserID bigint NOT NULL,
        MenuCode nvarchar(20) NOT NULL,
        PreferencesJson nvarchar(max) NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_TDADUserListDisplayPreference_UpdateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TDADUserListDisplayPreference PRIMARY KEY (UserType, UserID, MenuCode),
        CONSTRAINT CK_TDADUserListDisplayPreference_UserType CHECK (UserType IN ('L', 'P', 'C')),
        CONSTRAINT CK_TDADUserListDisplayPreference_Json CHECK (ISJSON(PreferencesJson) = 1)
    );
END;
