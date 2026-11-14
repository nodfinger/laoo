IF COL_LENGTH(N'dbo.TDADMeetingRoom', N'HasRoomDisplay') IS NULL
    ALTER TABLE dbo.TDADMeetingRoom ADD HasRoomDisplay bit NOT NULL
        CONSTRAINT DF_TDADMeetingRoom_HasRoomDisplay DEFAULT (0);
