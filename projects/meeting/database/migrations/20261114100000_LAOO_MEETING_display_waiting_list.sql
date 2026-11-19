IF COL_LENGTH(N'dbo.TDADMeetingDisplayVisibility', N'ShowWaitingList') IS NULL
    ALTER TABLE dbo.TDADMeetingDisplayVisibility ADD ShowWaitingList bit NOT NULL
        CONSTRAINT DF_TDADMeetingDisplayVisibility_ShowWaitingList DEFAULT (0);
