/* Approved schema: one meeting room can have many employee contacts.
   Department is intentionally not stored; it is used only as a lookup filter. */
IF OBJECT_ID(N'dbo.TDADMeetingRoomContact', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomContact
    (
        RoomID BIGINT NOT NULL,
        EmployeeID BIGINT NOT NULL,
        Remark NVARCHAR(500) NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_TDADMeetingRoomContact_IsActive DEFAULT (1),
        CreateDate DATETIME2 NOT NULL
            CONSTRAINT DF_TDADMeetingRoomContact_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2 NULL,
        CONSTRAINT PK_TDADMeetingRoomContact
            PRIMARY KEY (RoomID, EmployeeID),
        CONSTRAINT FK_TDADMeetingRoomContact_Room
            FOREIGN KEY (RoomID)
            REFERENCES dbo.TDADMeetingRoom(RoomID)
            ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingRoomContact_Employee
            FOREIGN KEY (EmployeeID)
            REFERENCES dbo.TDADEmployee(EmployeeID)
    );

    CREATE INDEX IX_TDADMeetingRoomContact_Employee
        ON dbo.TDADMeetingRoomContact(EmployeeID, IsActive);
END;
