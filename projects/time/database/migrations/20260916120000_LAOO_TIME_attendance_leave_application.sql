SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDTMAttendanceResult', N'U') IS NULL
        THROW 52670, N'Attendance result foundation is required.', 1;
    IF OBJECT_ID(N'dbo.TDTMLeaveRequestDate', N'U') IS NULL
        THROW 52671, N'Leave request foundation is required.', 1;

    IF OBJECT_ID(N'dbo.TDTMAttendanceLeaveApplication', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMAttendanceLeaveApplication
        (
            AttendanceLeaveApplicationID bigint IDENTITY(1,1) NOT NULL
                CONSTRAINT PK_TDTMAttendanceLeaveApplication PRIMARY KEY,
            CompanyID bigint NOT NULL,
            AttendanceResultID bigint NOT NULL,
            LeaveRequestID bigint NOT NULL,
            LeaveRequestDateID bigint NOT NULL,
            AppliedLeaveMinutes int NOT NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMAttendanceLeaveApplication_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendanceLeaveApplication_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMAttendanceLeaveApplication_CorrelationID DEFAULT(newid()),
            RowVersion rowversion NOT NULL,
            CONSTRAINT CK_TDTMAttendanceLeaveApplication_Minutes CHECK(AppliedLeaveMinutes > 0),
            CONSTRAINT FK_TDTMAttendanceLeaveApplication_Result FOREIGN KEY(AttendanceResultID) REFERENCES dbo.TDTMAttendanceResult(AttendanceResultID),
            CONSTRAINT FK_TDTMAttendanceLeaveApplication_RequestDate FOREIGN KEY(LeaveRequestDateID) REFERENCES dbo.TDTMLeaveRequestDate(LeaveRequestDateID)
        );
        CREATE UNIQUE INDEX UX_TDTMAttendanceLeaveApplication_Active
            ON dbo.TDTMAttendanceLeaveApplication(AttendanceResultID, LeaveRequestDateID)
            WHERE IsActive=1;
        CREATE INDEX IX_TDTMAttendanceLeaveApplication_Request
            ON dbo.TDTMAttendanceLeaveApplication(CompanyID, LeaveRequestID, IsActive);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
