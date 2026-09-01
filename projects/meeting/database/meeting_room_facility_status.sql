/* Approved migration: room-specific facility availability. */
IF COL_LENGTH('dbo.TDADMeetingRoomFacility', 'IsActive') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingRoomFacility
        ADD IsActive BIT NOT NULL
            CONSTRAINT DF_TDADMeetingRoomFacility_IsActive DEFAULT (1) WITH VALUES;
END;
