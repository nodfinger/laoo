SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT V.MenuCode,V.ScreenType
        FROM (VALUES('26001',4),('26002',3),('28003',1),('28004',1),('30001',4))V(MenuCode,ScreenType)
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.TDADMainMenu M
            WHERE M.MenuCode=V.MenuCode AND M.ScreenType=V.ScreenType AND M.IsActive=1
        )
    )
        THROW 52501,N'Center/Core menu and ScreenType bootstrap is required before the Time correction migration.',1;

    IF OBJECT_ID(N'dbo.TDTMTimeAdjustmentReason',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMTimeAdjustmentReason
        (
            TimeAdjustmentReasonID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMTimeAdjustmentReason PRIMARY KEY,
            CompanyID bigint NOT NULL,
            ReasonCode nvarchar(50) NOT NULL,
            ReasonName nvarchar(200) NOT NULL,
            RequireRemark bit NOT NULL CONSTRAINT DF_TDTMTimeAdjustmentReason_RequireRemark DEFAULT(1),
            RequireEvidence bit NOT NULL CONSTRAINT DF_TDTMTimeAdjustmentReason_RequireEvidence DEFAULT(0),
            IsActive bit NOT NULL CONSTRAINT DF_TDTMTimeAdjustmentReason_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMTimeAdjustmentReason_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT UQ_TDTMTimeAdjustmentReason_Code UNIQUE(CompanyID,ReasonCode)
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMTimeCorrectionRequest',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMTimeCorrectionRequest
        (
            RequestID bigint NOT NULL CONSTRAINT PK_TDTMTimeCorrectionRequest PRIMARY KEY,
            CompanyID bigint NOT NULL,
            SubjectEmployeeID bigint NOT NULL,
            WorkDate date NOT NULL,
            TimeAdjustmentReasonID bigint NOT NULL,
            RequestRemark nvarchar(1000) NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMTimeCorrectionRequest_CreateDate DEFAULT(sysdatetime()),
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMTimeCorrectionRequest_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDTMRequest(RequestID),
            CONSTRAINT FK_TDTMTimeCorrectionRequest_Reason FOREIGN KEY(TimeAdjustmentReasonID) REFERENCES dbo.TDTMTimeAdjustmentReason(TimeAdjustmentReasonID)
        );
        CREATE INDEX IX_TDTMTimeCorrectionRequest_EmployeeDate
            ON dbo.TDTMTimeCorrectionRequest(CompanyID,SubjectEmployeeID,WorkDate,RequestID);
    END;

    IF OBJECT_ID(N'dbo.TDTMTimeCorrectionDetail',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMTimeCorrectionDetail
        (
            TimeCorrectionDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMTimeCorrectionDetail PRIMARY KEY,
            RequestID bigint NOT NULL,
            CompanyID bigint NOT NULL,
            SubjectEmployeeID bigint NOT NULL,
            WorkDate date NOT NULL,
            SequenceNo int NOT NULL,
            AttendanceSessionRuleID bigint NOT NULL,
            SessionName nvarchar(100) NOT NULL,
            EndpointCode varchar(10) NOT NULL,
            OriginalDateTime datetime2(3) NULL,
            RequestedDateTime datetime2(3) NOT NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMTimeCorrectionDetail_CreateDate DEFAULT(sysdatetime()),
            CONSTRAINT FK_TDTMTimeCorrectionDetail_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDTMTimeCorrectionRequest(RequestID),
            CONSTRAINT FK_TDTMTimeCorrectionDetail_Session FOREIGN KEY(AttendanceSessionRuleID) REFERENCES dbo.TDTMAttendanceSessionRule(AttendanceSessionRuleID),
            CONSTRAINT CK_TDTMTimeCorrectionDetail_Sequence CHECK(SequenceNo>0),
            CONSTRAINT CK_TDTMTimeCorrectionDetail_Endpoint CHECK(EndpointCode IN('IN','OUT')),
            CONSTRAINT UQ_TDTMTimeCorrectionDetail_Sequence UNIQUE(RequestID,SequenceNo),
            CONSTRAINT UQ_TDTMTimeCorrectionDetail_Endpoint UNIQUE(RequestID,AttendanceSessionRuleID,EndpointCode)
        );
        CREATE INDEX IX_TDTMTimeCorrectionDetail_ActiveCheck
            ON dbo.TDTMTimeCorrectionDetail(CompanyID,SubjectEmployeeID,WorkDate,AttendanceSessionRuleID,EndpointCode,RequestID);
    END;

    IF OBJECT_ID(N'dbo.TDTMTimeAdjustment',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMTimeAdjustment
        (
            TimeAdjustmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMTimeAdjustment PRIMARY KEY,
            CompanyID bigint NOT NULL,
            RequestID bigint NOT NULL,
            TimeCorrectionDetailID bigint NOT NULL,
            SubjectEmployeeID bigint NOT NULL,
            WorkDate date NOT NULL,
            AttendanceSessionRuleID bigint NOT NULL,
            SessionName nvarchar(100) NOT NULL,
            EndpointCode varchar(10) NOT NULL,
            AdjustedDateTime datetime2(3) NOT NULL,
            SupersedesTimeAdjustmentID bigint NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMTimeAdjustment_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NOT NULL,
            CorrelationID uniqueidentifier NOT NULL,
            CONSTRAINT FK_TDTMTimeAdjustment_Request FOREIGN KEY(RequestID) REFERENCES dbo.TDTMRequest(RequestID),
            CONSTRAINT FK_TDTMTimeAdjustment_Detail FOREIGN KEY(TimeCorrectionDetailID) REFERENCES dbo.TDTMTimeCorrectionDetail(TimeCorrectionDetailID),
            CONSTRAINT FK_TDTMTimeAdjustment_Session FOREIGN KEY(AttendanceSessionRuleID) REFERENCES dbo.TDTMAttendanceSessionRule(AttendanceSessionRuleID),
            CONSTRAINT FK_TDTMTimeAdjustment_Supersedes FOREIGN KEY(SupersedesTimeAdjustmentID) REFERENCES dbo.TDTMTimeAdjustment(TimeAdjustmentID),
            CONSTRAINT UQ_TDTMTimeAdjustment_Detail UNIQUE(TimeCorrectionDetailID),
            CONSTRAINT UQ_TDTMTimeAdjustment_Correlation UNIQUE(CompanyID,CorrelationID)
        );
        CREATE INDEX IX_TDTMTimeAdjustment_Effective
            ON dbo.TDTMTimeAdjustment(CompanyID,SubjectEmployeeID,WorkDate,AttendanceSessionRuleID,EndpointCode,CreateDate DESC);
    END;

    IF OBJECT_ID(N'dbo.TR_TDTMTimeAdjustment_Immutable',N'TR') IS NULL
        EXEC(N'CREATE TRIGGER dbo.TR_TDTMTimeAdjustment_Immutable ON dbo.TDTMTimeAdjustment INSTEAD OF UPDATE,DELETE AS THROW 52520,N''Time adjustments are immutable; create a superseding adjustment.'',1;');

    -- Center/Core owns menu, route, ScreenType and permission bootstrap.  Keep the
    -- reviewed seed definition below as a contract, but never mutate Core here.
    IF 1=0
    BEGIN
    DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME');
    IF @ProjectID IS NULL THROW 52501,N'LAOO_TIME project is required.',1;

    DECLARE @Menus TABLE
    (
        MenuCode char(5) PRIMARY KEY,MenuGroupCode char(2),MenuName nvarchar(150),
        ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),
        FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int
    );
    INSERT @Menus VALUES
        ('26001','26',N'คำขอปรับเวลา',4,N'timeCorrectionProxy',N'/company/time-corrections',N'TIME_CORRECTION_PROXY',N'edit_calendar_outlined',10),
        ('26002','26',N'กล่องอนุมัติคำขอเวลา',3,N'timeApprovalInbox',N'/company/time-approval-inbox',N'TIME_APPROVAL_INBOX',N'approval_outlined',20),
        ('28003','28',N'เหตุผลทำแทน',1,N'timeOnBehalfReasons',N'/company/time-on-behalf-reasons',N'TIME_ON_BEHALF_REASON',N'person_add_alt_outlined',30),
        ('28004','28',N'เหตุผลปรับเวลา',1,N'timeAdjustmentReasons',N'/company/time-adjustment-reasons',N'TIME_ADJUSTMENT_REASON',N'rule_outlined',40),
        ('30001','30',N'คำขอปรับเวลาของฉัน',4,N'myTimeCorrections',N'/company/my-time-corrections',N'TIME_CORRECTION_SELF',N'edit_calendar_outlined',10);

    IF EXISTS(SELECT 1 FROM @Menus S JOIN dbo.TDADMainMenu T ON T.MenuCode=S.MenuCode WHERE T.ScreenType<>S.ScreenType OR ISNULL(T.RouteName,N'')<>S.RouteName OR ISNULL(T.RoutePath,N'')<>S.RoutePath)
        THROW 52502,N'LAOO_TIME correction MenuCode conflicts with an existing menu.',1;

    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    SELECT MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,sysdatetime(),0
    FROM @Menus S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu T WHERE T.MenuCode=S.MenuCode);
    UPDATE T SET MenuName=S.MenuName,FeatureCode=S.FeatureCode,IconName=S.IconName,SortOrder=S.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,UpdateDate=sysdatetime()
    FROM dbo.TDADMainMenu T JOIN @Menus S ON S.MenuCode=T.MenuCode;

    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @ProjectID,MenuCode,MenuGroupCode,SortOrder,1,sysdatetime() FROM @Menus S
    WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu T WHERE T.ProjectID=@ProjectID AND T.MenuCode=S.MenuCode);
    UPDATE T SET MenuGroupCode=S.MenuGroupCode,SortOrder=S.SortOrder,IsActive=1,UpdateDate=sysdatetime()
    FROM dbo.TDADProjectMenu T JOIN @Menus S ON S.MenuCode=T.MenuCode WHERE T.ProjectID=@ProjectID;

    UPDATE dbo.TDADMenuGroup SET IsActive=1,UpdateDate=sysdatetime() WHERE MenuGroupCode IN('26','28','30');
    UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=sysdatetime() WHERE ProjectID=@ProjectID AND MenuGroupCode IN('26','28','30');

    DECLARE @Permissions TABLE(ScreenCode nvarchar(50),ScreenNameTH nvarchar(200),ActionCode nvarchar(50),ActionNameTH nvarchar(200),PRIMARY KEY(ScreenCode,ActionCode));
    INSERT @Permissions VALUES
        (N'26001',N'คำขอปรับเวลา',N'VIEW',N'ดูข้อมูล'),(N'26001',N'คำขอปรับเวลา',N'CREATE',N'สร้างคำขอ'),
        (N'26001',N'คำขอปรับเวลา',N'ACT_ON_BEHALF',N'ทำรายการแทน'),(N'26001',N'คำขอปรับเวลา',N'APPROVE',N'อนุมัติ'),
        (N'26001',N'คำขอปรับเวลา',N'SELF_APPROVE',N'อนุมัติรายการตนเอง'),
        (N'26002',N'กล่องอนุมัติคำขอเวลา',N'VIEW',N'ดูข้อมูล'),(N'26002',N'กล่องอนุมัติคำขอเวลา',N'APPROVE',N'อนุมัติ'),
        (N'26002',N'กล่องอนุมัติคำขอเวลา',N'SELF_APPROVE',N'อนุมัติรายการตนเอง'),
        (N'28003',N'เหตุผลทำแทน',N'VIEW',N'ดูข้อมูล'),(N'28003',N'เหตุผลทำแทน',N'CREATE',N'เพิ่มข้อมูล'),(N'28003',N'เหตุผลทำแทน',N'EDIT',N'แก้ไขข้อมูล'),(N'28003',N'เหตุผลทำแทน',N'DELETE',N'ลบข้อมูล'),
        (N'28004',N'เหตุผลปรับเวลา',N'VIEW',N'ดูข้อมูล'),(N'28004',N'เหตุผลปรับเวลา',N'CREATE',N'เพิ่มข้อมูล'),(N'28004',N'เหตุผลปรับเวลา',N'EDIT',N'แก้ไขข้อมูล'),(N'28004',N'เหตุผลปรับเวลา',N'DELETE',N'ลบข้อมูล'),
        (N'30001',N'คำขอปรับเวลาของฉัน',N'VIEW',N'ดูข้อมูล'),(N'30001',N'คำขอปรับเวลาของฉัน',N'CREATE',N'สร้างคำขอ'),(N'30001',N'คำขอปรับเวลาของฉัน',N'SUBMIT',N'ส่งคำขอ'),(N'30001',N'คำขอปรับเวลาของฉัน',N'CANCEL',N'ยกเลิกคำขอ');

    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @ProjectID,P.ScreenCode,P.ScreenNameTH,P.ScreenNameTH,P.ActionCode,P.ActionNameTH,P.ActionNameTH,1,sysdatetime()
    FROM @Permissions P WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission X WHERE X.ProjectID=@ProjectID AND X.ScreenCode=P.ScreenCode AND X.ActionCode=P.ActionCode);

    INSERT dbo.TDTMApprovalProfileVersion(CompanyID,ProfileCode,EffectiveFrom,IsActive)
    SELECT C.CompanyID,'OWNER_OPERATED',CONVERT(date,'20000101'),1 FROM dbo.TDSTCompanySetUp C
    WHERE C.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDTMApprovalProfileVersion V WHERE V.CompanyID=C.CompanyID);

    INSERT dbo.TDTMEmployeeRequestPolicyVersion(CompanyID,ProcessCode,PolicyCode,EffectiveFrom,IsActive)
    SELECT C.CompanyID,P.ProcessCode,'SELF_SERVICE_AND_PROXY',CONVERT(date,'20000101'),1
    FROM dbo.TDSTCompanySetUp C CROSS JOIN(VALUES('LEAVE_REQUEST'),('LEAVE_CANCELLATION'),('TIME_CORRECTION'),('RECONFIRMATION'))P(ProcessCode)
    WHERE C.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDTMEmployeeRequestPolicyVersion V WHERE V.CompanyID=C.CompanyID AND V.ProcessCode=P.ProcessCode);
    END;

    INSERT dbo.TDTMOnBehalfReason(CompanyID,ReasonCode,ReasonName,RequireRemark,RequireEvidence,IsActive)
    SELECT C.CompanyID,N'ADMIN_REQUEST',N'พนักงานแจ้งให้ผู้ดูแลดำเนินการแทน',1,0,1 FROM dbo.TDSTCompanySetUp C
    WHERE C.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDTMOnBehalfReason R WHERE R.CompanyID=C.CompanyID AND R.ReasonCode=N'ADMIN_REQUEST');

    INSERT dbo.TDTMTimeAdjustmentReason(CompanyID,ReasonCode,ReasonName,RequireRemark,RequireEvidence,IsActive)
    SELECT C.CompanyID,V.Code,V.Name,1,V.Evidence,1 FROM dbo.TDSTCompanySetUp C
    CROSS JOIN(VALUES(N'FORGOT_PUNCH',N'ลืมลงเวลาทำงาน',CAST(0 AS bit)),(N'DEVICE_FAILURE',N'เครื่องบันทึกเวลาทำงานขัดข้อง',CAST(1 AS bit)),(N'OTHER',N'เหตุผลอื่น',CAST(0 AS bit)))V(Code,Name,Evidence)
    WHERE C.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDTMTimeAdjustmentReason R WHERE R.CompanyID=C.CompanyID AND R.ReasonCode=V.Code);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
