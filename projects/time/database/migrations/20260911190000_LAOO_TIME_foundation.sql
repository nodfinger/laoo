SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDTMApprovalProfileVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMApprovalProfileVersion
    (
        ApprovalProfileVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMApprovalProfileVersion PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ProfileCode varchar(30) NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMApprovalProfileVersion_IsActive DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMApprovalProfileVersion_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMApprovalProfileVersion_Profile CHECK (ProfileCode IN ('OWNER_OPERATED','SEGREGATED_WORKFLOW')),
        CONSTRAINT CK_TDTMApprovalProfileVersion_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT UQ_TDTMApprovalProfileVersion_Start UNIQUE (CompanyID, EffectiveFrom)
    );
    CREATE UNIQUE INDEX UX_TDTMApprovalProfileVersion_Open
        ON dbo.TDTMApprovalProfileVersion(CompanyID) WHERE EffectiveTo IS NULL AND IsActive = 1;
END;

IF OBJECT_ID(N'dbo.TDTMProcessApprovalPolicyVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMProcessApprovalPolicyVersion
    (
        ProcessApprovalPolicyVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMProcessApprovalPolicyVersion PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ProcessCode varchar(20) NOT NULL,
        ProfileCode varchar(30) NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMProcessApprovalPolicyVersion_IsActive DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMProcessApprovalPolicyVersion_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMProcessApprovalPolicyVersion_Process CHECK (ProcessCode IN ('LEAVE','TIME','OT','ENTITLEMENT','PERIOD')),
        CONSTRAINT CK_TDTMProcessApprovalPolicyVersion_Profile CHECK (ProfileCode IN ('OWNER_OPERATED','SEGREGATED_WORKFLOW')),
        CONSTRAINT CK_TDTMProcessApprovalPolicyVersion_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT UQ_TDTMProcessApprovalPolicyVersion_Start UNIQUE (CompanyID, ProcessCode, EffectiveFrom)
    );
    CREATE UNIQUE INDEX UX_TDTMProcessApprovalPolicyVersion_Open
        ON dbo.TDTMProcessApprovalPolicyVersion(CompanyID, ProcessCode)
        WHERE EffectiveTo IS NULL AND IsActive = 1;
END;

IF OBJECT_ID(N'dbo.TDTMEmployeeRequestPolicyVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMEmployeeRequestPolicyVersion
    (
        RequestPolicyVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMEmployeeRequestPolicyVersion PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ProcessCode varchar(30) NOT NULL,
        PolicyCode varchar(30) NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMEmployeeRequestPolicyVersion_IsActive DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMEmployeeRequestPolicyVersion_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMEmployeeRequestPolicyVersion_Process CHECK (ProcessCode IN ('LEAVE_REQUEST','LEAVE_CANCELLATION','TIME_CORRECTION','RECONFIRMATION')),
        CONSTRAINT CK_TDTMEmployeeRequestPolicyVersion_Policy CHECK (PolicyCode IN ('SELF_SERVICE_AND_PROXY','PROXY_ONLY','SELF_SERVICE_ONLY')),
        CONSTRAINT CK_TDTMEmployeeRequestPolicyVersion_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT UQ_TDTMEmployeeRequestPolicyVersion_Start UNIQUE (CompanyID, ProcessCode, EffectiveFrom)
    );
    CREATE UNIQUE INDEX UX_TDTMEmployeeRequestPolicyVersion_Open
        ON dbo.TDTMEmployeeRequestPolicyVersion(CompanyID, ProcessCode)
        WHERE EffectiveTo IS NULL AND IsActive = 1;
END;

IF OBJECT_ID(N'dbo.TDTMApprovalRouteVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMApprovalRouteVersion
    (
        ApprovalRouteVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMApprovalRouteVersion PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ProcessCode varchar(20) NOT NULL,
        QualifierTypeCode varchar(30) NOT NULL,
        QualifierID bigint NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMApprovalRouteVersion_IsActive DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMApprovalRouteVersion_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMApprovalRouteVersion_Process CHECK (ProcessCode IN ('LEAVE','TIME','OT','ENTITLEMENT','PERIOD')),
        CONSTRAINT CK_TDTMApprovalRouteVersion_Qualifier CHECK
            ((QualifierTypeCode = 'DEFAULT' AND QualifierID IS NULL) OR
             (QualifierTypeCode IN ('LEAVE_TYPE','ADJUSTMENT_REASON','OT_DAY_CATEGORY','EMPLOYEE_GROUP') AND QualifierID IS NOT NULL)),
        CONSTRAINT CK_TDTMApprovalRouteVersion_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT UQ_TDTMApprovalRouteVersion_Start UNIQUE (CompanyID, ProcessCode, QualifierTypeCode, QualifierID, EffectiveFrom)
    );
    CREATE INDEX IX_TDTMApprovalRouteVersion_Resolve
        ON dbo.TDTMApprovalRouteVersion(CompanyID, ProcessCode, QualifierTypeCode, QualifierID, EffectiveFrom, EffectiveTo);
END;

IF OBJECT_ID(N'dbo.TDTMApprovalRouteStep', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMApprovalRouteStep
    (
        ApprovalRouteStepID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMApprovalRouteStep PRIMARY KEY,
        ApprovalRouteVersionID bigint NOT NULL,
        StepOrder int NOT NULL,
        AssigneeTypeCode varchar(20) NOT NULL,
        AssigneeRoleGroupID bigint NULL,
        RequiredPermissionCode varchar(50) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMApprovalRouteStep_CreateDate DEFAULT (sysdatetime()),
        CONSTRAINT FK_TDTMApprovalRouteStep_Route FOREIGN KEY (ApprovalRouteVersionID)
            REFERENCES dbo.TDTMApprovalRouteVersion(ApprovalRouteVersionID),
        CONSTRAINT CK_TDTMApprovalRouteStep_Order CHECK (StepOrder > 0),
        CONSTRAINT CK_TDTMApprovalRouteStep_Assignee CHECK
            ((AssigneeTypeCode = 'ROLE_GROUP' AND AssigneeRoleGroupID IS NOT NULL) OR
             (AssigneeTypeCode IN ('SUPERVISOR','COMPANY_ADMIN','REQUEST_SUBJECT') AND AssigneeRoleGroupID IS NULL)),
        CONSTRAINT UQ_TDTMApprovalRouteStep_Order UNIQUE (ApprovalRouteVersionID, StepOrder)
    );
END;

IF OBJECT_ID(N'dbo.TDTMOnBehalfReason', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMOnBehalfReason
    (
        OnBehalfReasonID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMOnBehalfReason PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ReasonCode nvarchar(50) NOT NULL,
        ReasonName nvarchar(200) NOT NULL,
        RequireRemark bit NOT NULL CONSTRAINT DF_TDTMOnBehalfReason_RequireRemark DEFAULT (1),
        RequireEvidence bit NOT NULL CONSTRAINT DF_TDTMOnBehalfReason_RequireEvidence DEFAULT (0),
        IsActive bit NOT NULL CONSTRAINT DF_TDTMOnBehalfReason_IsActive DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMOnBehalfReason_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDTMOnBehalfReason_Code UNIQUE (CompanyID, ReasonCode)
    );
END;

IF OBJECT_ID(N'dbo.TDTMAttendanceRequirement', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAttendanceRequirement
    (
        AttendanceRequirementID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendanceRequirement PRIMARY KEY,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        RequirementCode varchar(20) NOT NULL,
        EffectiveFrom date NOT NULL,
        EffectiveTo date NULL,
        Reason nvarchar(500) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendanceRequirement_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMAttendanceRequirement_Code CHECK (RequirementCode IN ('REQUIRED','EXEMPT')),
        CONSTRAINT CK_TDTMAttendanceRequirement_Date CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
        CONSTRAINT UQ_TDTMAttendanceRequirement_Start UNIQUE (CompanyID, EmployeeID, EffectiveFrom)
    );
    CREATE UNIQUE INDEX UX_TDTMAttendanceRequirement_Open
        ON dbo.TDTMAttendanceRequirement(CompanyID, EmployeeID) WHERE EffectiveTo IS NULL;
END;

IF OBJECT_ID(N'dbo.TDTMAttendanceDeviceCodeAssignment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAttendanceDeviceCodeAssignment
    (
        DeviceCodeAssignmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendanceDeviceCodeAssignment PRIMARY KEY,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        DeviceCode nvarchar(100) NOT NULL,
        EffectiveFromDateTime datetime2(3) NOT NULL,
        EffectiveToDateTime datetime2(3) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAttendanceDeviceCodeAssignment_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMAttendanceDeviceCodeAssignment_Date CHECK (EffectiveToDateTime IS NULL OR EffectiveToDateTime > EffectiveFromDateTime),
        CONSTRAINT UQ_TDTMAttendanceDeviceCodeAssignment_Start UNIQUE (CompanyID, EmployeeID, EffectiveFromDateTime)
    );
    CREATE UNIQUE INDEX UX_TDTMAttendanceDeviceCodeAssignment_OpenEmployee
        ON dbo.TDTMAttendanceDeviceCodeAssignment(CompanyID, EmployeeID) WHERE EffectiveToDateTime IS NULL;
    CREATE UNIQUE INDEX UX_TDTMAttendanceDeviceCodeAssignment_OpenCode
        ON dbo.TDTMAttendanceDeviceCodeAssignment(CompanyID, DeviceCode) WHERE EffectiveToDateTime IS NULL;
    CREATE INDEX IX_TDTMAttendanceDeviceCodeAssignment_Resolve
        ON dbo.TDTMAttendanceDeviceCodeAssignment(CompanyID, DeviceCode, EffectiveFromDateTime, EffectiveToDateTime) INCLUDE (EmployeeID);
END;

IF OBJECT_ID(N'dbo.TDTMEmployeeTimeSettingAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMEmployeeTimeSettingAudit
    (
        EmployeeTimeSettingAuditID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMEmployeeTimeSettingAudit PRIMARY KEY,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        SettingTypeCode varchar(40) NOT NULL,
        BeforeJson nvarchar(max) NULL,
        AfterJson nvarchar(max) NOT NULL,
        Reason nvarchar(1000) NOT NULL,
        ActorUserID bigint NOT NULL,
        OccurredDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMEmployeeTimeSettingAudit_OccurredDate DEFAULT (sysdatetime()),
        CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMEmployeeTimeSettingAudit_CorrelationID DEFAULT (newid()),
        CONSTRAINT CK_TDTMEmployeeTimeSettingAudit_BeforeJson CHECK (BeforeJson IS NULL OR ISJSON(BeforeJson) = 1),
        CONSTRAINT CK_TDTMEmployeeTimeSettingAudit_AfterJson CHECK (ISJSON(AfterJson) = 1)
    );
    CREATE INDEX IX_TDTMEmployeeTimeSettingAudit_Employee
        ON dbo.TDTMEmployeeTimeSettingAudit(CompanyID, EmployeeID, OccurredDate DESC);
END;

IF OBJECT_ID(N'dbo.TDTMDelegatedTimeAdministration', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMDelegatedTimeAdministration
    (
        DelegationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMDelegatedTimeAdministration PRIMARY KEY,
        CompanyID bigint NOT NULL,
        PartnerID bigint NOT NULL,
        PartnerUserID bigint NOT NULL,
        EffectiveFrom datetime2(3) NOT NULL,
        EffectiveTo datetime2(3) NULL,
        StatusCode varchar(20) NOT NULL,
        Reason nvarchar(1000) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMDelegatedTimeAdministration_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMDelegatedTimeAdministration_Status CHECK (StatusCode IN ('ACTIVE','REVOKED','EXPIRED')),
        CONSTRAINT CK_TDTMDelegatedTimeAdministration_Date CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom)
    );
    CREATE INDEX IX_TDTMDelegatedTimeAdministration_Resolve
        ON dbo.TDTMDelegatedTimeAdministration(CompanyID, PartnerID, PartnerUserID, EffectiveFrom, EffectiveTo, StatusCode);
END;

IF OBJECT_ID(N'dbo.TDTMDelegatedTimePermission', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMDelegatedTimePermission
    (
        DelegationID bigint NOT NULL,
        ActionCode varchar(50) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMDelegatedTimePermission_CreateDate DEFAULT (sysdatetime()),
        CONSTRAINT PK_TDTMDelegatedTimePermission PRIMARY KEY (DelegationID, ActionCode),
        CONSTRAINT FK_TDTMDelegatedTimePermission_Delegation FOREIGN KEY (DelegationID)
            REFERENCES dbo.TDTMDelegatedTimeAdministration(DelegationID)
    );
END;

IF OBJECT_ID(N'dbo.TDTMEmployeeDataScopeGrant', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMEmployeeDataScopeGrant
    (
        ScopeGrantID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMEmployeeDataScopeGrant PRIMARY KEY,
        CompanyID bigint NOT NULL,
        UserID bigint NULL,
        RoleGroupID bigint NULL,
        DelegationID bigint NULL,
        ScopeTypeCode varchar(20) NOT NULL,
        ScopeReferenceID bigint NULL,
        EffectiveFrom datetime2(3) NOT NULL,
        EffectiveTo datetime2(3) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDTMEmployeeDataScopeGrant_IsActive DEFAULT (1),
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMEmployeeDataScopeGrant_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMEmployeeDataScopeGrant_Delegation FOREIGN KEY (DelegationID)
            REFERENCES dbo.TDTMDelegatedTimeAdministration(DelegationID),
        CONSTRAINT CK_TDTMEmployeeDataScopeGrant_Owner CHECK
            ((CASE WHEN UserID IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN RoleGroupID IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN DelegationID IS NULL THEN 0 ELSE 1 END) = 1),
        CONSTRAINT CK_TDTMEmployeeDataScopeGrant_Scope CHECK
            ((ScopeTypeCode IN ('SELF','ALL','SUPERVISOR') AND ScopeReferenceID IS NULL) OR
             (ScopeTypeCode IN ('BRANCH','DIVISION','DEPARTMENT') AND ScopeReferenceID IS NOT NULL)),
        CONSTRAINT CK_TDTMEmployeeDataScopeGrant_Date CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom)
    );
    CREATE INDEX IX_TDTMEmployeeDataScopeGrant_Company
        ON dbo.TDTMEmployeeDataScopeGrant(CompanyID, ScopeTypeCode, EffectiveFrom, EffectiveTo, IsActive);
END;

IF OBJECT_ID(N'dbo.TDTMEmployeeRequestAccessGap', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMEmployeeRequestAccessGap
    (
        AccessGapID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMEmployeeRequestAccessGap PRIMARY KEY,
        CompanyID bigint NOT NULL,
        EmployeeID bigint NOT NULL,
        ProcessCode varchar(30) NOT NULL,
        DetectedDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMEmployeeRequestAccessGap_DetectedDate DEFAULT (sysdatetime()),
        StatusCode varchar(20) NOT NULL CONSTRAINT DF_TDTMEmployeeRequestAccessGap_Status DEFAULT ('OPEN'),
        ResolvedDate datetime2(3) NULL,
        ResolvedByUserID bigint NULL,
        ResolutionRemark nvarchar(1000) NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT CK_TDTMEmployeeRequestAccessGap_Process CHECK (ProcessCode IN ('LEAVE_REQUEST','LEAVE_CANCELLATION','TIME_CORRECTION','RECONFIRMATION')),
        CONSTRAINT CK_TDTMEmployeeRequestAccessGap_Status CHECK (StatusCode IN ('OPEN','RESOLVED','WAIVED')),
        CONSTRAINT CK_TDTMEmployeeRequestAccessGap_Resolution CHECK
            ((StatusCode = 'OPEN' AND ResolvedDate IS NULL AND ResolvedByUserID IS NULL) OR
             (StatusCode IN ('RESOLVED','WAIVED') AND ResolvedDate IS NOT NULL AND ResolvedByUserID IS NOT NULL))
    );
    CREATE UNIQUE INDEX UX_TDTMEmployeeRequestAccessGap_Open
        ON dbo.TDTMEmployeeRequestAccessGap(CompanyID, EmployeeID, ProcessCode) WHERE StatusCode = 'OPEN';
END;

IF OBJECT_ID(N'dbo.TDTMRequest', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMRequest
    (
        RequestID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMRequest PRIMARY KEY,
        CompanyID bigint NOT NULL,
        ProcessCode varchar(30) NOT NULL,
        SubjectEmployeeID bigint NOT NULL,
        InitiationModeCode varchar(10) NOT NULL,
        ActorUserID bigint NOT NULL,
        OnBehalfReasonID bigint NULL,
        OnBehalfRemark nvarchar(1000) NULL,
        EvidenceReference nvarchar(1000) NULL,
        StatusCode varchar(20) NOT NULL,
        SubmittedDate datetime2(3) NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMRequest_CreateDate DEFAULT (sysdatetime()),
        CreateBy bigint NOT NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMRequest_OnBehalfReason FOREIGN KEY (OnBehalfReasonID)
            REFERENCES dbo.TDTMOnBehalfReason(OnBehalfReasonID),
        CONSTRAINT CK_TDTMRequest_Process CHECK (ProcessCode IN ('LEAVE_REQUEST','LEAVE_CANCELLATION','TIME_CORRECTION','RECONFIRMATION')),
        CONSTRAINT CK_TDTMRequest_Initiation CHECK
            ((InitiationModeCode = 'SELF' AND OnBehalfReasonID IS NULL) OR
             (InitiationModeCode = 'PROXY' AND OnBehalfReasonID IS NOT NULL)),
        CONSTRAINT CK_TDTMRequest_Status CHECK (StatusCode IN ('PENDING','APPROVED','REJECTED','CANCELLED','EXPIRED')),
        CONSTRAINT CK_TDTMRequest_Submitted CHECK (StatusCode = 'PENDING' OR SubmittedDate IS NOT NULL)
    );
    CREATE INDEX IX_TDTMRequest_Subject
        ON dbo.TDTMRequest(CompanyID, SubjectEmployeeID, ProcessCode, StatusCode, CreateDate DESC);
END;

IF OBJECT_ID(N'dbo.TDTMWorkflowSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMWorkflowSnapshot
    (
        WorkflowSnapshotID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMWorkflowSnapshot PRIMARY KEY,
        RequestID bigint NOT NULL,
        ApprovalProfileVersionID bigint NULL,
        ProcessApprovalPolicyVersionID bigint NULL,
        ApprovalRouteVersionID bigint NULL,
        SnapshotJson nvarchar(max) NOT NULL,
        SnapshotHash varbinary(32) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMWorkflowSnapshot_CreateDate DEFAULT (sysdatetime()),
        CONSTRAINT FK_TDTMWorkflowSnapshot_Request FOREIGN KEY (RequestID) REFERENCES dbo.TDTMRequest(RequestID),
        CONSTRAINT CK_TDTMWorkflowSnapshot_Json CHECK (ISJSON(SnapshotJson) = 1),
        CONSTRAINT UQ_TDTMWorkflowSnapshot_Request UNIQUE (RequestID)
    );
END;

IF OBJECT_ID(N'dbo.TDTMRequestPolicySnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMRequestPolicySnapshot
    (
        RequestPolicySnapshotID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMRequestPolicySnapshot PRIMARY KEY,
        RequestID bigint NOT NULL,
        RequestPolicyVersionID bigint NOT NULL,
        PolicyCode varchar(30) NOT NULL,
        SnapshotJson nvarchar(max) NOT NULL,
        SnapshotHash varbinary(32) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMRequestPolicySnapshot_CreateDate DEFAULT (sysdatetime()),
        CONSTRAINT FK_TDTMRequestPolicySnapshot_Request FOREIGN KEY (RequestID) REFERENCES dbo.TDTMRequest(RequestID),
        CONSTRAINT FK_TDTMRequestPolicySnapshot_Policy FOREIGN KEY (RequestPolicyVersionID)
            REFERENCES dbo.TDTMEmployeeRequestPolicyVersion(RequestPolicyVersionID),
        CONSTRAINT CK_TDTMRequestPolicySnapshot_Policy CHECK (PolicyCode IN ('SELF_SERVICE_AND_PROXY','PROXY_ONLY','SELF_SERVICE_ONLY')),
        CONSTRAINT CK_TDTMRequestPolicySnapshot_Json CHECK (ISJSON(SnapshotJson) = 1),
        CONSTRAINT UQ_TDTMRequestPolicySnapshot_Request UNIQUE (RequestID)
    );
END;

IF OBJECT_ID(N'dbo.TDTMApprovalDecision', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMApprovalDecision
    (
        ApprovalDecisionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMApprovalDecision PRIMARY KEY,
        RequestID bigint NOT NULL,
        StepOrder int NOT NULL,
        DecisionCode varchar(20) NOT NULL,
        ActorUserID bigint NOT NULL,
        ActorEmployeeID bigint NULL,
        IsSelfApproved bit NOT NULL CONSTRAINT DF_TDTMApprovalDecision_IsSelfApproved DEFAULT (0),
        Reason nvarchar(1000) NULL,
        EvidenceReference nvarchar(1000) NULL,
        DecisionDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMApprovalDecision_DecisionDate DEFAULT (sysdatetime()),
        CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMApprovalDecision_CorrelationID DEFAULT (newid()),
        CONSTRAINT FK_TDTMApprovalDecision_Request FOREIGN KEY (RequestID) REFERENCES dbo.TDTMRequest(RequestID),
        CONSTRAINT CK_TDTMApprovalDecision_Order CHECK (StepOrder >= 0),
        CONSTRAINT CK_TDTMApprovalDecision_Code CHECK (DecisionCode IN ('APPROVED','REJECTED','CANCELLED','REOPENED')),
        CONSTRAINT UQ_TDTMApprovalDecision_Step UNIQUE (RequestID, StepOrder, DecisionCode)
    );
    CREATE INDEX IX_TDTMApprovalDecision_Request ON dbo.TDTMApprovalDecision(RequestID, DecisionDate);
END;

IF OBJECT_ID(N'dbo.TDTMRequestEditLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMRequestEditLog
    (
        RequestEditLogID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMRequestEditLog PRIMARY KEY,
        RequestID bigint NOT NULL,
        FieldPath nvarchar(300) NOT NULL,
        BeforeValue nvarchar(max) NULL,
        AfterValue nvarchar(max) NULL,
        Reason nvarchar(1000) NOT NULL,
        ActorUserID bigint NOT NULL,
        ChangedDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMRequestEditLog_ChangedDate DEFAULT (sysdatetime()),
        CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMRequestEditLog_CorrelationID DEFAULT (newid()),
        CONSTRAINT FK_TDTMRequestEditLog_Request FOREIGN KEY (RequestID) REFERENCES dbo.TDTMRequest(RequestID)
    );
    CREATE INDEX IX_TDTMRequestEditLog_Request ON dbo.TDTMRequestEditLog(RequestID, ChangedDate);
END;

IF OBJECT_ID(N'dbo.TDTMAdministrativeOverride', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMAdministrativeOverride
    (
        AdministrativeOverrideID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAdministrativeOverride PRIMARY KEY,
        CompanyID bigint NOT NULL,
        OverrideTypeCode varchar(50) NOT NULL,
        TargetTypeCode varchar(50) NOT NULL,
        TargetID bigint NULL,
        BeforeJson nvarchar(max) NULL,
        AfterJson nvarchar(max) NOT NULL,
        Reason nvarchar(1000) NOT NULL,
        ActorUserID bigint NOT NULL,
        OccurredDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMAdministrativeOverride_OccurredDate DEFAULT (sysdatetime()),
        CorrelationID uniqueidentifier NOT NULL,
        CONSTRAINT CK_TDTMAdministrativeOverride_BeforeJson CHECK (BeforeJson IS NULL OR ISJSON(BeforeJson) = 1),
        CONSTRAINT CK_TDTMAdministrativeOverride_AfterJson CHECK (ISJSON(AfterJson) = 1),
        CONSTRAINT UQ_TDTMAdministrativeOverride_Correlation UNIQUE (CompanyID, CorrelationID)
    );
    CREATE INDEX IX_TDTMAdministrativeOverride_Target
        ON dbo.TDTMAdministrativeOverride(CompanyID, TargetTypeCode, TargetID, OccurredDate DESC);
END;

IF OBJECT_ID(N'dbo.TDTMNotificationDelivery', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDTMNotificationDelivery
    (
        NotificationDeliveryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMNotificationDelivery PRIMARY KEY,
        CompanyID bigint NOT NULL,
        RequestID bigint NULL,
        RecipientEmployeeID bigint NOT NULL,
        ChannelCode varchar(20) NOT NULL,
        StatusCode varchar(20) NOT NULL CONSTRAINT DF_TDTMNotificationDelivery_Status DEFAULT ('PENDING'),
        AttemptCount int NOT NULL CONSTRAINT DF_TDTMNotificationDelivery_AttemptCount DEFAULT (0),
        LastAttemptDate datetime2(3) NULL,
        LastError nvarchar(2000) NULL,
        PayloadJson nvarchar(max) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMNotificationDelivery_CreateDate DEFAULT (sysdatetime()),
        CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMNotificationDelivery_CorrelationID DEFAULT (newid()),
        RowVersion rowversion NOT NULL,
        CONSTRAINT FK_TDTMNotificationDelivery_Request FOREIGN KEY (RequestID) REFERENCES dbo.TDTMRequest(RequestID),
        CONSTRAINT CK_TDTMNotificationDelivery_Channel CHECK (ChannelCode IN ('IN_APP','EMAIL','SMS','LINE')),
        CONSTRAINT CK_TDTMNotificationDelivery_Status CHECK (StatusCode IN ('PENDING','PROCESSING','DELIVERED','FAILED')),
        CONSTRAINT CK_TDTMNotificationDelivery_Attempt CHECK (AttemptCount >= 0),
        CONSTRAINT CK_TDTMNotificationDelivery_Payload CHECK (ISJSON(PayloadJson) = 1)
    );
    CREATE INDEX IX_TDTMNotificationDelivery_Outbox
        ON dbo.TDTMNotificationDelivery(StatusCode, CreateDate) INCLUDE (CompanyID, RequestID, AttemptCount);
END;

SELECT t.name AS TableName
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID(N'dbo') AND t.name LIKE N'TDTM%'
ORDER BY t.name;
