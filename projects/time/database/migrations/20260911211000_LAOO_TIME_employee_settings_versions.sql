SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDTMAttendanceRequirement', N'SupersededUtc') IS NULL
    ALTER TABLE dbo.TDTMAttendanceRequirement ADD SupersededUtc datetime2(3) NULL;
IF COL_LENGTH(N'dbo.TDTMAttendanceRequirement', N'SupersededBy') IS NULL
    ALTER TABLE dbo.TDTMAttendanceRequirement ADD SupersededBy bigint NULL;

IF COL_LENGTH(N'dbo.TDTMAttendanceDeviceCodeAssignment', N'SupersededUtc') IS NULL
    ALTER TABLE dbo.TDTMAttendanceDeviceCodeAssignment ADD SupersededUtc datetime2(3) NULL;
IF COL_LENGTH(N'dbo.TDTMAttendanceDeviceCodeAssignment', N'SupersededBy') IS NULL
    ALTER TABLE dbo.TDTMAttendanceDeviceCodeAssignment ADD SupersededBy bigint NULL;
GO

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_TDTMAttendanceRequirement_Start')
    ALTER TABLE dbo.TDTMAttendanceRequirement DROP CONSTRAINT UQ_TDTMAttendanceRequirement_Start;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceRequirement') AND name=N'UX_TDTMAttendanceRequirement_Open')
    DROP INDEX UX_TDTMAttendanceRequirement_Open ON dbo.TDTMAttendanceRequirement;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceRequirement') AND name=N'UX_TDTMAttendanceRequirement_CurrentStart')
    CREATE UNIQUE INDEX UX_TDTMAttendanceRequirement_CurrentStart
        ON dbo.TDTMAttendanceRequirement(CompanyID,EmployeeID,EffectiveFrom)
        WHERE SupersededUtc IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceRequirement') AND name=N'UX_TDTMAttendanceRequirement_CurrentOpen')
    CREATE UNIQUE INDEX UX_TDTMAttendanceRequirement_CurrentOpen
        ON dbo.TDTMAttendanceRequirement(CompanyID,EmployeeID)
        WHERE EffectiveTo IS NULL AND SupersededUtc IS NULL;

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_TDTMAttendanceDeviceCodeAssignment_Start')
    ALTER TABLE dbo.TDTMAttendanceDeviceCodeAssignment DROP CONSTRAINT UQ_TDTMAttendanceDeviceCodeAssignment_Start;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceDeviceCodeAssignment') AND name=N'UX_TDTMAttendanceDeviceCodeAssignment_OpenEmployee')
    DROP INDEX UX_TDTMAttendanceDeviceCodeAssignment_OpenEmployee ON dbo.TDTMAttendanceDeviceCodeAssignment;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceDeviceCodeAssignment') AND name=N'UX_TDTMAttendanceDeviceCodeAssignment_OpenCode')
    DROP INDEX UX_TDTMAttendanceDeviceCodeAssignment_OpenCode ON dbo.TDTMAttendanceDeviceCodeAssignment;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceDeviceCodeAssignment') AND name=N'UX_TDTMAttendanceDeviceCodeAssignment_CurrentStart')
    CREATE UNIQUE INDEX UX_TDTMAttendanceDeviceCodeAssignment_CurrentStart
        ON dbo.TDTMAttendanceDeviceCodeAssignment(CompanyID,EmployeeID,EffectiveFromDateTime)
        WHERE SupersededUtc IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceDeviceCodeAssignment') AND name=N'UX_TDTMAttendanceDeviceCodeAssignment_CurrentOpenEmployee')
    CREATE UNIQUE INDEX UX_TDTMAttendanceDeviceCodeAssignment_CurrentOpenEmployee
        ON dbo.TDTMAttendanceDeviceCodeAssignment(CompanyID,EmployeeID)
        WHERE EffectiveToDateTime IS NULL AND SupersededUtc IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMAttendanceDeviceCodeAssignment') AND name=N'UX_TDTMAttendanceDeviceCodeAssignment_CurrentOpenCode')
    CREATE UNIQUE INDEX UX_TDTMAttendanceDeviceCodeAssignment_CurrentOpenCode
        ON dbo.TDTMAttendanceDeviceCodeAssignment(CompanyID,DeviceCode)
        WHERE EffectiveToDateTime IS NULL AND SupersededUtc IS NULL;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMAttendanceRequirement_NoOverlap
ON dbo.TDTMAttendanceRequirement
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.TDTMAttendanceRequirement x WITH (UPDLOCK,HOLDLOCK)
          ON x.CompanyID=i.CompanyID AND x.EmployeeID=i.EmployeeID
         AND x.AttendanceRequirementID<>i.AttendanceRequirementID
         AND x.SupersededUtc IS NULL AND i.SupersededUtc IS NULL
         AND i.EffectiveFrom<=ISNULL(x.EffectiveTo,CONVERT(date,'99991231'))
         AND x.EffectiveFrom<=ISNULL(i.EffectiveTo,CONVERT(date,'99991231'))
    ) THROW 52405,'Attendance requirement effective dates overlap.',1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMAttendanceDeviceCodeAssignment_NoOverlap
ON dbo.TDTMAttendanceDeviceCodeAssignment
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.TDTMAttendanceDeviceCodeAssignment x WITH (UPDLOCK,HOLDLOCK)
          ON x.CompanyID=i.CompanyID
         AND (x.EmployeeID=i.EmployeeID OR x.DeviceCode=i.DeviceCode)
         AND x.DeviceCodeAssignmentID<>i.DeviceCodeAssignmentID
         AND x.SupersededUtc IS NULL AND i.SupersededUtc IS NULL
         AND i.EffectiveFromDateTime<ISNULL(x.EffectiveToDateTime,CONVERT(datetime2(3),'9999-12-31T23:59:59.999'))
         AND x.EffectiveFromDateTime<ISNULL(i.EffectiveToDateTime,CONVERT(datetime2(3),'9999-12-31T23:59:59.999'))
    ) THROW 52406,'Attendance device-code assignments overlap for an employee or device code.',1;
END;
GO
