/* Replace the Meeting-owned facility master with Core Item equipment. */
IF OBJECT_ID(N'dbo.TDADMeetingRoomItem', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomItem
    (
        RoomID BIGINT NOT NULL,
        ItemID BIGINT NOT NULL,
        Quantity INT NULL,
        Remark NVARCHAR(500) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDADMeetingRoomItem_IsActive DEFAULT (1),
        CreateDate DATETIME2(3) NOT NULL CONSTRAINT DF_TDADMeetingRoomItem_CreateDate DEFAULT SYSUTCDATETIME(),
        UpdateDate DATETIME2(3) NULL,
        CONSTRAINT PK_TDADMeetingRoomItem PRIMARY KEY (RoomID, ItemID),
        CONSTRAINT FK_TDADMeetingRoomItem_Room FOREIGN KEY (RoomID)
            REFERENCES dbo.TDADMeetingRoom(RoomID) ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingRoomItem_Item FOREIGN KEY (ItemID)
            REFERENCES dbo.TDIVItem(ItemID)
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomItem')
      AND name = N'IX_TDADMeetingRoomItem_Item'
)
    CREATE INDEX IX_TDADMeetingRoomItem_Item
        ON dbo.TDADMeetingRoomItem (ItemID, RoomID);

IF OBJECT_ID(N'dbo.TDADMeetingRoomIssue', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomIssue
    (
        IssueID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingRoomIssue PRIMARY KEY,
        CompanyID BIGINT NOT NULL,
        RoomID BIGINT NOT NULL,
        ItemID BIGINT NOT NULL,
        ReportedByUserID BIGINT NOT NULL,
        Description NVARCHAR(2000) NOT NULL,
        ImageUrl NVARCHAR(500) NULL,
        StatusCode NVARCHAR(20) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomIssue_Status DEFAULT (N'OPEN'),
        CreateDate DATETIME2(3) NOT NULL
            CONSTRAINT DF_TDADMeetingRoomIssue_CreateDate DEFAULT SYSUTCDATETIME(),
        UpdateDate DATETIME2(3) NULL,
        CONSTRAINT FK_TDADMeetingRoomIssue_Room FOREIGN KEY (RoomID)
            REFERENCES dbo.TDADMeetingRoom(RoomID),
        CONSTRAINT FK_TDADMeetingRoomIssue_Item FOREIGN KEY (ItemID)
            REFERENCES dbo.TDIVItem(ItemID),
        CONSTRAINT CK_TDADMeetingRoomIssue_Status
            CHECK (StatusCode IN (N'OPEN', N'IN_PROGRESS', N'RESOLVED', N'CANCELLED'))
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingRoomIssue')
      AND name = N'IX_TDADMeetingRoomIssue_Company_Status'
)
    CREATE INDEX IX_TDADMeetingRoomIssue_Company_Status
        ON dbo.TDADMeetingRoomIssue (CompanyID, StatusCode, CreateDate);

/* The old master and room relation are Meeting-owned and are intentionally not migrated. */
IF OBJECT_ID(N'dbo.TDADMeetingRoomFacility', N'U') IS NOT NULL
    DROP TABLE dbo.TDADMeetingRoomFacility;

IF OBJECT_ID(N'dbo.TDADMeetingFacility', N'U') IS NOT NULL
    DROP TABLE dbo.TDADMeetingFacility;
