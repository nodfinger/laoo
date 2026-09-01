/* Approved schema for MenuCode 15002 - Meeting Rooms. */
CREATE TABLE dbo.TDADMeetingRoom (
    RoomID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingRoom PRIMARY KEY,
    CompanyID BIGINT NOT NULL,
    BuildingID BIGINT NULL,
    FloorID BIGINT NULL,
    RoomCode NVARCHAR(50) NOT NULL,
    RoomNameTH NVARCHAR(200) NOT NULL,
    Capacity INT NULL,
    Description NVARCHAR(1000) NULL,
    RoomImageUrl NVARCHAR(500) NULL,
    LocationImageUrl NVARCHAR(500) NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_TDADMeetingRoom_IsActive DEFAULT(1),
    CreateDate DATETIME2 NOT NULL CONSTRAINT DF_TDADMeetingRoom_CreateDate DEFAULT(SYSUTCDATETIME()),
    UpdateDate DATETIME2 NULL
);
CREATE UNIQUE INDEX UX_TDADMeetingRoom_Company_Code ON dbo.TDADMeetingRoom(CompanyID, RoomCode);
CREATE INDEX IX_TDADMeetingRoom_Company ON dbo.TDADMeetingRoom(CompanyID, BuildingID, FloorID);

CREATE TABLE dbo.TDADMeetingRoomFacility (
    RoomID BIGINT NOT NULL,
    FacilityID BIGINT NOT NULL,
    Quantity INT NULL,
    Remark NVARCHAR(500) NULL,
    CreateDate DATETIME2 NOT NULL CONSTRAINT DF_TDADMeetingRoomFacility_CreateDate DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT PK_TDADMeetingRoomFacility PRIMARY KEY(RoomID, FacilityID),
    CONSTRAINT FK_TDADMeetingRoomFacility_Room FOREIGN KEY(RoomID) REFERENCES dbo.TDADMeetingRoom(RoomID) ON DELETE CASCADE,
    CONSTRAINT FK_TDADMeetingRoomFacility_Facility FOREIGN KEY(FacilityID) REFERENCES dbo.TDADMeetingFacility(FacilityID)
);
