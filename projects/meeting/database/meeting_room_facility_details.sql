/* Approved migration: meeting-room facility quantity and remark. */
IF COL_LENGTH('dbo.TDADMeetingRoomFacility', 'Quantity') IS NULL
    ALTER TABLE dbo.TDADMeetingRoomFacility ADD Quantity INT NULL;
IF COL_LENGTH('dbo.TDADMeetingRoomFacility', 'Remark') IS NULL
    ALTER TABLE dbo.TDADMeetingRoomFacility ADD Remark NVARCHAR(500) NULL;
