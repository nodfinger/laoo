IF OBJECT_ID(N'dbo.TDADUserProfile', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADUserProfile
    (
        ProfileID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADUserProfile PRIMARY KEY,
        UserType CHAR(1) NOT NULL,
        LaooUserID BIGINT NULL,
        PartnerUserID BIGINT NULL,
        UserID BIGINT NULL,
        AvatarData VARBINARY(MAX) NULL,
        AvatarContentType NVARCHAR(100) NULL,
        AvatarFileName NVARCHAR(250) NULL,
        ThemeCode NVARCHAR(30) NULL,
        Introduction NVARCHAR(1000) NULL,
        CreateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADUserProfile_CreateDate DEFAULT SYSUTCDATETIME(),
        UpdateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADUserProfile_UpdateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_TDADUserProfile_UserType CHECK (UserType IN ('L','P','C')),
        CONSTRAINT CK_TDADUserProfile_OneOwner CHECK
        ((UserType='L' AND LaooUserID IS NOT NULL AND PartnerUserID IS NULL AND UserID IS NULL)
          OR (UserType='P' AND LaooUserID IS NULL AND PartnerUserID IS NOT NULL AND UserID IS NULL)
          OR (UserType='C' AND LaooUserID IS NULL AND PartnerUserID IS NULL AND UserID IS NOT NULL))
    );
    CREATE UNIQUE INDEX UX_TDADUserProfile_Laoo ON dbo.TDADUserProfile(LaooUserID) WHERE LaooUserID IS NOT NULL;
    CREATE UNIQUE INDEX UX_TDADUserProfile_Partner ON dbo.TDADUserProfile(PartnerUserID) WHERE PartnerUserID IS NOT NULL;
    CREATE UNIQUE INDEX UX_TDADUserProfile_User ON dbo.TDADUserProfile(UserID) WHERE UserID IS NOT NULL;
END;
