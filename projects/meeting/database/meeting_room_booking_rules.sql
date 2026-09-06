USE [DBTDMeeting];
GO

/* Child Action Screen of MenuCode 15002 - Meeting Rooms. */
IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingRule', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingRule (
        RuleID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingRoomBookingRule PRIMARY KEY,
        CompanyID BIGINT NOT NULL,
        RoomID BIGINT NOT NULL,
        ApprovalMode VARCHAR(20) NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingRule_ApprovalMode DEFAULT ('NONE'),
        MaxAdvanceDays INT NULL,
        MaxDurationMinutes INT NULL,
        CancelBeforeMinutes INT NULL,
        RequireAllApprovers BIT NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingRule_RequireAll DEFAULT (1),
        Remark NVARCHAR(1000) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingRule_IsActive DEFAULT (1),
        CreateDate DATETIME2 NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingRule_CreateDate DEFAULT (SYSUTCDATETIME()),
        UpdateDate DATETIME2 NULL,
        CONSTRAINT UX_TDADMeetingRoomBookingRule_Company_Room UNIQUE (CompanyID, RoomID),
        CONSTRAINT FK_TDADMeetingRoomBookingRule_Room FOREIGN KEY (RoomID) REFERENCES dbo.TDADMeetingRoom(RoomID) ON DELETE CASCADE,
        CONSTRAINT CK_TDADMeetingRoomBookingRule_ApprovalMode CHECK (ApprovalMode IN ('NONE','LINE_MANAGER','SELECTED'))
    );
END;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_TDADMeetingRoomBookingRule_ApprovalMode' AND parent_object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBookingRule'))
    ALTER TABLE dbo.TDADMeetingRoomBookingRule DROP CONSTRAINT CK_TDADMeetingRoomBookingRule_ApprovalMode;
GO
ALTER TABLE dbo.TDADMeetingRoomBookingRule
    ADD CONSTRAINT CK_TDADMeetingRoomBookingRule_ApprovalMode CHECK (ApprovalMode IN ('NONE','LINE_MANAGER','SELECTED'));
GO

IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingRuleApprover', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingRuleApprover (
        RuleID BIGINT NOT NULL,
        EmployeeID BIGINT NOT NULL,
        ApprovalOrder INT NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingRuleApprover_Order DEFAULT (1),
        CreateDate DATETIME2 NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingRuleApprover_CreateDate DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_TDADMeetingRoomBookingRuleApprover PRIMARY KEY (RuleID, EmployeeID),
        CONSTRAINT FK_TDADMeetingRoomBookingRuleApprover_Rule FOREIGN KEY (RuleID) REFERENCES dbo.TDADMeetingRoomBookingRule(RuleID) ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingRoomBookingRuleApprover_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_TDADMeetingRoomBookingRule_Company' AND object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBookingRule'))
    CREATE INDEX IX_TDADMeetingRoomBookingRule_Company ON dbo.TDADMeetingRoomBookingRule(CompanyID, IsActive);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_TDADMeetingRoomBookingRuleApprover_Employee' AND object_id = OBJECT_ID(N'dbo.TDADMeetingRoomBookingRuleApprover'))
    CREATE INDEX IX_TDADMeetingRoomBookingRuleApprover_Employee ON dbo.TDADMeetingRoomBookingRuleApprover(EmployeeID);
GO
