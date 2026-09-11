SET NOCOUNT ON;
SET XACT_ABORT ON;

ALTER TABLE dbo.TDTMRequest DROP CONSTRAINT CK_TDTMRequest_Submitted;
ALTER TABLE dbo.TDTMRequest ADD CONSTRAINT CK_TDTMRequest_Submitted CHECK (SubmittedDate IS NOT NULL);
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMApprovalProfileVersion_NoOverlap
ON dbo.TDTMApprovalProfileVersion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.TDTMApprovalProfileVersion x WITH (UPDLOCK, HOLDLOCK)
          ON x.CompanyID = i.CompanyID
         AND x.ApprovalProfileVersionID <> i.ApprovalProfileVersionID
         AND x.IsActive = 1 AND i.IsActive = 1
         AND i.EffectiveFrom <= ISNULL(x.EffectiveTo, CONVERT(date,'99991231'))
         AND x.EffectiveFrom <= ISNULL(i.EffectiveTo, CONVERT(date,'99991231'))
    ) THROW 52401, 'Approval profile effective dates overlap.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMProcessApprovalPolicyVersion_NoOverlap
ON dbo.TDTMProcessApprovalPolicyVersion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.TDTMProcessApprovalPolicyVersion x WITH (UPDLOCK, HOLDLOCK)
          ON x.CompanyID = i.CompanyID AND x.ProcessCode = i.ProcessCode
         AND x.ProcessApprovalPolicyVersionID <> i.ProcessApprovalPolicyVersionID
         AND x.IsActive = 1 AND i.IsActive = 1
         AND i.EffectiveFrom <= ISNULL(x.EffectiveTo, CONVERT(date,'99991231'))
         AND x.EffectiveFrom <= ISNULL(i.EffectiveTo, CONVERT(date,'99991231'))
    ) THROW 52402, 'Process approval policy effective dates overlap.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMEmployeeRequestPolicyVersion_NoOverlap
ON dbo.TDTMEmployeeRequestPolicyVersion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.TDTMEmployeeRequestPolicyVersion x WITH (UPDLOCK, HOLDLOCK)
          ON x.CompanyID = i.CompanyID AND x.ProcessCode = i.ProcessCode
         AND x.RequestPolicyVersionID <> i.RequestPolicyVersionID
         AND x.IsActive = 1 AND i.IsActive = 1
         AND i.EffectiveFrom <= ISNULL(x.EffectiveTo, CONVERT(date,'99991231'))
         AND x.EffectiveFrom <= ISNULL(i.EffectiveTo, CONVERT(date,'99991231'))
    ) THROW 52403, 'Employee request policy effective dates overlap.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMApprovalRouteVersion_NoOverlap
ON dbo.TDTMApprovalRouteVersion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.TDTMApprovalRouteVersion x WITH (UPDLOCK, HOLDLOCK)
          ON x.CompanyID = i.CompanyID AND x.ProcessCode = i.ProcessCode
         AND x.QualifierTypeCode = i.QualifierTypeCode
         AND (x.QualifierID = i.QualifierID OR (x.QualifierID IS NULL AND i.QualifierID IS NULL))
         AND x.ApprovalRouteVersionID <> i.ApprovalRouteVersionID
         AND x.IsActive = 1 AND i.IsActive = 1
         AND i.EffectiveFrom <= ISNULL(x.EffectiveTo, CONVERT(date,'99991231'))
         AND x.EffectiveFrom <= ISNULL(i.EffectiveTo, CONVERT(date,'99991231'))
    ) THROW 52404, 'Approval route effective dates overlap.', 1;
END;
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
        JOIN dbo.TDTMAttendanceRequirement x WITH (UPDLOCK, HOLDLOCK)
          ON x.CompanyID = i.CompanyID AND x.EmployeeID = i.EmployeeID
         AND x.AttendanceRequirementID <> i.AttendanceRequirementID
         AND i.EffectiveFrom <= ISNULL(x.EffectiveTo, CONVERT(date,'99991231'))
         AND x.EffectiveFrom <= ISNULL(i.EffectiveTo, CONVERT(date,'99991231'))
    ) THROW 52405, 'Attendance requirement effective dates overlap.', 1;
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
        JOIN dbo.TDTMAttendanceDeviceCodeAssignment x WITH (UPDLOCK, HOLDLOCK)
          ON x.CompanyID = i.CompanyID
         AND (x.EmployeeID = i.EmployeeID OR x.DeviceCode = i.DeviceCode)
         AND x.DeviceCodeAssignmentID <> i.DeviceCodeAssignmentID
         AND i.EffectiveFromDateTime < ISNULL(x.EffectiveToDateTime, CONVERT(datetime2(3),'9999-12-31T23:59:59.999'))
         AND x.EffectiveFromDateTime < ISNULL(i.EffectiveToDateTime, CONVERT(datetime2(3),'9999-12-31T23:59:59.999'))
    ) THROW 52406, 'Attendance device-code assignments overlap for an employee or device code.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMRequest_ValidateProxy
ON dbo.TDTMRequest
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.TDTMOnBehalfReason r ON r.OnBehalfReasonID = i.OnBehalfReasonID
        WHERE i.InitiationModeCode = 'PROXY'
          AND (r.CompanyID <> i.CompanyID OR r.IsActive = 0
               OR (r.RequireRemark = 1 AND NULLIF(LTRIM(RTRIM(i.OnBehalfRemark)),N'') IS NULL)
               OR (r.RequireEvidence = 1 AND NULLIF(LTRIM(RTRIM(i.EvidenceReference)),N'') IS NULL))
    ) THROW 52407, 'Proxy reason is invalid, inactive, belongs to another company, or lacks required evidence.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMWorkflowSnapshot_Immutable
ON dbo.TDTMWorkflowSnapshot INSTEAD OF UPDATE, DELETE
AS THROW 52420, 'Workflow snapshots are immutable.', 1;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMRequestPolicySnapshot_Immutable
ON dbo.TDTMRequestPolicySnapshot INSTEAD OF UPDATE, DELETE
AS THROW 52421, 'Request policy snapshots are immutable.', 1;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMApprovalDecision_Immutable
ON dbo.TDTMApprovalDecision INSTEAD OF UPDATE, DELETE
AS THROW 52422, 'Approval decisions are append-only.', 1;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMRequestEditLog_Immutable
ON dbo.TDTMRequestEditLog INSTEAD OF UPDATE, DELETE
AS THROW 52423, 'Request edit logs are append-only.', 1;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMAdministrativeOverride_Immutable
ON dbo.TDTMAdministrativeOverride INSTEAD OF UPDATE, DELETE
AS THROW 52424, 'Administrative overrides are append-only.', 1;
GO

CREATE OR ALTER TRIGGER dbo.TR_TDTMEmployeeTimeSettingAudit_Immutable
ON dbo.TDTMEmployeeTimeSettingAudit INSTEAD OF UPDATE, DELETE
AS THROW 52425, 'Employee time-setting audit records are append-only.', 1;
GO
