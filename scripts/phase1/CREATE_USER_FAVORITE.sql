/*
  User Favorite Menu
  L = Laoo support user
  P = Partner user
  C = Company/customer user
*/
IF OBJECT_ID(N'dbo.TDADUserFavorite', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADUserFavorite
    (
        UserFavoriteID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADUserFavorite PRIMARY KEY,
        UserType CHAR(1) NOT NULL,
        LaooUserID BIGINT NULL,
        PartnerUserID BIGINT NULL,
        UserID BIGINT NULL,
        MenuCode NVARCHAR(20) NOT NULL,
        SortOrder INT NOT NULL
            CONSTRAINT DF_TDADUserFavorite_SortOrder DEFAULT (0),
        CreateDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADUserFavorite_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2(0) NULL,

        CONSTRAINT CK_TDADUserFavorite_UserType
            CHECK (UserType IN ('L', 'P', 'C')),
        CONSTRAINT CK_TDADUserFavorite_Owner
            CHECK (
                (UserType = 'L' AND LaooUserID IS NOT NULL AND PartnerUserID IS NULL AND UserID IS NULL)
                OR (UserType = 'P' AND LaooUserID IS NULL AND PartnerUserID IS NOT NULL AND UserID IS NULL)
                OR (UserType = 'C' AND LaooUserID IS NULL AND PartnerUserID IS NULL AND UserID IS NOT NULL)
            )
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_TDADUserFavorite_Laoo'
      AND object_id = OBJECT_ID(N'dbo.TDADUserFavorite')
)
    CREATE UNIQUE INDEX UX_TDADUserFavorite_Laoo
        ON dbo.TDADUserFavorite (LaooUserID, MenuCode)
        WHERE UserType = 'L';
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_TDADUserFavorite_Partner'
      AND object_id = OBJECT_ID(N'dbo.TDADUserFavorite')
)
    CREATE UNIQUE INDEX UX_TDADUserFavorite_Partner
        ON dbo.TDADUserFavorite (PartnerUserID, MenuCode)
        WHERE UserType = 'P';
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_TDADUserFavorite_Company'
      AND object_id = OBJECT_ID(N'dbo.TDADUserFavorite')
)
    CREATE UNIQUE INDEX UX_TDADUserFavorite_Company
        ON dbo.TDADUserFavorite (UserID, MenuCode)
        WHERE UserType = 'C';
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_TDADUserFavorite_Sort'
      AND object_id = OBJECT_ID(N'dbo.TDADUserFavorite')
)
    CREATE INDEX IX_TDADUserFavorite_Sort
        ON dbo.TDADUserFavorite (UserType, SortOrder, MenuCode);
GO
