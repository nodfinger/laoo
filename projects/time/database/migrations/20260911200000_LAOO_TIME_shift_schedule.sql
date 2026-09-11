SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDTMShiftTemplate',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMShiftTemplate
        (
            ShiftTemplateID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMShiftTemplate PRIMARY KEY,
            CompanyID bigint NOT NULL,
            ShiftCode nvarchar(30) NOT NULL,
            ShiftName nvarchar(150) NOT NULL,
            DescriptionText nvarchar(500) NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMShiftTemplate_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMShiftTemplate_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT UQ_TDTMShiftTemplate_Code UNIQUE(CompanyID,ShiftCode)
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMShiftTemplateVersion',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMShiftTemplateVersion
        (
            ShiftTemplateVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMShiftTemplateVersion PRIMARY KEY,
            CompanyID bigint NOT NULL,
            ShiftTemplateID bigint NOT NULL,
            EffectiveFrom date NOT NULL,
            EffectiveTo date NULL,
            LateToleranceMinutes int NOT NULL CONSTRAINT DF_TDTMShiftVersion_Late DEFAULT(0),
            EarlyToleranceMinutes int NOT NULL CONSTRAINT DF_TDTMShiftVersion_Early DEFAULT(0),
            IsActive bit NOT NULL CONSTRAINT DF_TDTMShiftVersion_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMShiftVersion_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMShiftVersion_Template FOREIGN KEY(ShiftTemplateID) REFERENCES dbo.TDTMShiftTemplate(ShiftTemplateID),
            CONSTRAINT CK_TDTMShiftVersion_Date CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom),
            CONSTRAINT CK_TDTMShiftVersion_Tolerance CHECK(LateToleranceMinutes BETWEEN 0 AND 1440 AND EarlyToleranceMinutes BETWEEN 0 AND 1440),
            CONSTRAINT UQ_TDTMShiftVersion_Start UNIQUE(CompanyID,ShiftTemplateID,EffectiveFrom)
        );
        CREATE UNIQUE INDEX UX_TDTMShiftVersion_Open ON dbo.TDTMShiftTemplateVersion(CompanyID,ShiftTemplateID)
            WHERE EffectiveTo IS NULL AND IsActive=1;
    END;

    IF OBJECT_ID(N'dbo.TDTMShiftSegment',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMShiftSegment
        (
            ShiftSegmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMShiftSegment PRIMARY KEY,
            CompanyID bigint NOT NULL,
            ShiftTemplateVersionID bigint NOT NULL,
            SequenceNo int NOT NULL,
            SegmentTypeCode varchar(20) NOT NULL,
            StartDayOffset tinyint NOT NULL,
            StartTime time(0) NOT NULL,
            EndDayOffset tinyint NOT NULL,
            EndTime time(0) NOT NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMShiftSegment_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMShiftSegment_Version FOREIGN KEY(ShiftTemplateVersionID) REFERENCES dbo.TDTMShiftTemplateVersion(ShiftTemplateVersionID),
            CONSTRAINT CK_TDTMShiftSegment_Type CHECK(SegmentTypeCode IN('WORK','BREAK','OT')),
            CONSTRAINT CK_TDTMShiftSegment_Offset CHECK(StartDayOffset BETWEEN 0 AND 1 AND EndDayOffset BETWEEN 0 AND 1),
            CONSTRAINT CK_TDTMShiftSegment_Order CHECK(EndDayOffset>StartDayOffset OR (EndDayOffset=StartDayOffset AND EndTime>StartTime)),
            CONSTRAINT UQ_TDTMShiftSegment_Sequence UNIQUE(ShiftTemplateVersionID,SequenceNo)
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMAttendanceSessionRule',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMAttendanceSessionRule
        (
            AttendanceSessionRuleID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMAttendanceSessionRule PRIMARY KEY,
            CompanyID bigint NOT NULL,
            ShiftTemplateVersionID bigint NOT NULL,
            SequenceNo int NOT NULL,
            RuleName nvarchar(100) NOT NULL,
            ScheduledInDayOffset tinyint NOT NULL,
            ScheduledInTime time(0) NOT NULL,
            ScheduledOutDayOffset tinyint NOT NULL,
            ScheduledOutTime time(0) NOT NULL,
            InWindowStartDayOffset tinyint NOT NULL,
            InWindowStartTime time(0) NOT NULL,
            InWindowEndDayOffset tinyint NOT NULL,
            InWindowEndTime time(0) NOT NULL,
            OutWindowStartDayOffset tinyint NOT NULL,
            OutWindowStartTime time(0) NOT NULL,
            OutWindowEndDayOffset tinyint NOT NULL,
            OutWindowEndTime time(0) NOT NULL,
            LateToleranceMinutes int NULL,
            EarlyToleranceMinutes int NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMSessionRule_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMSessionRule_Version FOREIGN KEY(ShiftTemplateVersionID) REFERENCES dbo.TDTMShiftTemplateVersion(ShiftTemplateVersionID),
            CONSTRAINT CK_TDTMSessionRule_Tolerance CHECK((LateToleranceMinutes IS NULL OR LateToleranceMinutes BETWEEN 0 AND 1440) AND (EarlyToleranceMinutes IS NULL OR EarlyToleranceMinutes BETWEEN 0 AND 1440)),
            CONSTRAINT UQ_TDTMSessionRule_Sequence UNIQUE(ShiftTemplateVersionID,SequenceNo)
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMWorkScheduleGroup',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMWorkScheduleGroup
        (
            WorkScheduleGroupID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMWorkScheduleGroup PRIMARY KEY,
            CompanyID bigint NOT NULL,
            GroupCode nvarchar(30) NOT NULL,
            GroupName nvarchar(150) NOT NULL,
            DescriptionText nvarchar(500) NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMWorkScheduleGroup_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMWorkScheduleGroup_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT UQ_TDTMWorkScheduleGroup_Code UNIQUE(CompanyID,GroupCode)
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMRotationPattern',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMRotationPattern
        (
            RotationPatternID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMRotationPattern PRIMARY KEY,
            CompanyID bigint NOT NULL,
            PatternCode nvarchar(30) NOT NULL,
            PatternName nvarchar(150) NOT NULL,
            DescriptionText nvarchar(500) NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMRotationPattern_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMRotationPattern_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT UQ_TDTMRotationPattern_Code UNIQUE(CompanyID,PatternCode)
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMRotationPatternVersion',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMRotationPatternVersion
        (
            RotationPatternVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMRotationPatternVersion PRIMARY KEY,
            CompanyID bigint NOT NULL,
            RotationPatternID bigint NOT NULL,
            EffectiveFrom date NOT NULL,
            EffectiveTo date NULL,
            CycleDays int NOT NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMRotationVersion_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMRotationVersion_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMRotationVersion_Pattern FOREIGN KEY(RotationPatternID) REFERENCES dbo.TDTMRotationPattern(RotationPatternID),
            CONSTRAINT CK_TDTMRotationVersion_Cycle CHECK(CycleDays BETWEEN 1 AND 366),
            CONSTRAINT CK_TDTMRotationVersion_Date CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom),
            CONSTRAINT UQ_TDTMRotationVersion_Start UNIQUE(CompanyID,RotationPatternID,EffectiveFrom)
        );
        CREATE UNIQUE INDEX UX_TDTMRotationVersion_Open ON dbo.TDTMRotationPatternVersion(CompanyID,RotationPatternID)
            WHERE EffectiveTo IS NULL AND IsActive=1;
    END;

    IF OBJECT_ID(N'dbo.TDTMRotationDay',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMRotationDay
        (
            RotationDayID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMRotationDay PRIMARY KEY,
            CompanyID bigint NOT NULL,
            RotationPatternVersionID bigint NOT NULL,
            DayNo int NOT NULL,
            IsDayOff bit NOT NULL,
            ShiftTemplateID bigint NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMRotationDay_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            CONSTRAINT FK_TDTMRotationDay_Version FOREIGN KEY(RotationPatternVersionID) REFERENCES dbo.TDTMRotationPatternVersion(RotationPatternVersionID),
            CONSTRAINT FK_TDTMRotationDay_Shift FOREIGN KEY(ShiftTemplateID) REFERENCES dbo.TDTMShiftTemplate(ShiftTemplateID),
            CONSTRAINT CK_TDTMRotationDay_Value CHECK((IsDayOff=1 AND ShiftTemplateID IS NULL) OR (IsDayOff=0 AND ShiftTemplateID IS NOT NULL)),
            CONSTRAINT UQ_TDTMRotationDay_No UNIQUE(RotationPatternVersionID,DayNo)
        );
    END;

    IF OBJECT_ID(N'dbo.TDTMGroupShiftRotation',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMGroupShiftRotation
        (
            GroupShiftRotationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMGroupShiftRotation PRIMARY KEY,
            CompanyID bigint NOT NULL,
            WorkScheduleGroupID bigint NOT NULL,
            RotationPatternID bigint NOT NULL,
            AnchorDate date NOT NULL,
            EffectiveFrom date NOT NULL,
            EffectiveTo date NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMGroupShiftRotation_IsActive DEFAULT(1),
            Reason nvarchar(1000) NOT NULL,
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMGroupShiftRotation_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMGroupShiftRotation_Group FOREIGN KEY(WorkScheduleGroupID) REFERENCES dbo.TDTMWorkScheduleGroup(WorkScheduleGroupID),
            CONSTRAINT FK_TDTMGroupShiftRotation_Pattern FOREIGN KEY(RotationPatternID) REFERENCES dbo.TDTMRotationPattern(RotationPatternID),
            CONSTRAINT CK_TDTMGroupShiftRotation_Date CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom),
            CONSTRAINT UQ_TDTMGroupShiftRotation_Start UNIQUE(CompanyID,WorkScheduleGroupID,EffectiveFrom)
        );
        CREATE UNIQUE INDEX UX_TDTMGroupShiftRotation_Open ON dbo.TDTMGroupShiftRotation(CompanyID,WorkScheduleGroupID)
            WHERE EffectiveTo IS NULL AND IsActive=1;
    END;

    IF OBJECT_ID(N'dbo.TDTMWorkScheduleGroupAssignment',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMWorkScheduleGroupAssignment
        (
            WorkScheduleGroupAssignmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMWorkScheduleGroupAssignment PRIMARY KEY,
            CompanyID bigint NOT NULL,
            EmployeeID bigint NOT NULL,
            WorkScheduleGroupID bigint NOT NULL,
            EffectiveFrom date NOT NULL,
            EffectiveTo date NULL,
            Reason nvarchar(1000) NOT NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMGroupAssignment_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMGroupAssignment_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMGroupAssignment_Group FOREIGN KEY(WorkScheduleGroupID) REFERENCES dbo.TDTMWorkScheduleGroup(WorkScheduleGroupID),
            CONSTRAINT CK_TDTMGroupAssignment_Date CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom),
            CONSTRAINT UQ_TDTMGroupAssignment_Start UNIQUE(CompanyID,EmployeeID,EffectiveFrom)
        );
        CREATE UNIQUE INDEX UX_TDTMGroupAssignment_Open ON dbo.TDTMWorkScheduleGroupAssignment(CompanyID,EmployeeID)
            WHERE EffectiveTo IS NULL AND IsActive=1;
    END;

    IF OBJECT_ID(N'dbo.TDTMScheduleOverride',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTMScheduleOverride
        (
            ScheduleOverrideID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMScheduleOverride PRIMARY KEY,
            CompanyID bigint NOT NULL,
            EmployeeID bigint NOT NULL,
            WorkDate date NOT NULL,
            IsDayOff bit NOT NULL,
            ShiftTemplateID bigint NULL,
            WorkBranchID bigint NULL,
            Reason nvarchar(1000) NOT NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTMScheduleOverride_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMScheduleOverride_CreateDate DEFAULT(sysdatetime()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT FK_TDTMScheduleOverride_Shift FOREIGN KEY(ShiftTemplateID) REFERENCES dbo.TDTMShiftTemplate(ShiftTemplateID),
            CONSTRAINT CK_TDTMScheduleOverride_Value CHECK((IsDayOff=1 AND ShiftTemplateID IS NULL) OR (IsDayOff=0 AND ShiftTemplateID IS NOT NULL)),
            CONSTRAINT UQ_TDTMScheduleOverride_WorkDate UNIQUE(CompanyID,EmployeeID,WorkDate)
        );
    END;

    DECLARE @Menus TABLE
    (
        MenuCode char(5) PRIMARY KEY, MenuName nvarchar(150), RouteName nvarchar(150),
        RoutePath nvarchar(300), FeatureCode nvarchar(100), IconName nvarchar(100), SortOrder int
    );
    INSERT @Menus VALUES
        ('27001',N'Master กะทำงาน',N'timeShiftTemplates',N'/company/time-shift-templates',N'TIME_SHIFT_TEMPLATES',N'schedule_outlined',10),
        ('27002',N'กลุ่มตารางทำงาน',N'timeScheduleGroups',N'/company/time-schedule-groups',N'TIME_SCHEDULE_GROUPS',N'groups_outlined',20),
        ('27003',N'รูปแบบหมุนกะ',N'timeRotationPatterns',N'/company/time-rotation-patterns',N'TIME_ROTATION_PATTERNS',N'autorenew_outlined',30),
        ('27004',N'จัดตารางพนักงาน',N'timeEmployeeSchedules',N'/company/time-employee-schedules',N'TIME_EMPLOYEE_SCHEDULES',N'calendar_month_outlined',40);

    IF EXISTS(SELECT 1 FROM @Menus S JOIN dbo.TDADMainMenu M ON M.MenuCode=S.MenuCode
              WHERE M.ScreenType<>1 OR ISNULL(M.RouteName,N'')<>S.RouteName OR ISNULL(M.RoutePath,N'')<>S.RoutePath)
        THROW 52320,'LAOO_TIME schedule MenuCode conflicts with existing menu.',1;

    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,
        IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    SELECT MenuCode,'27',MenuName,1,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,0,SYSDATETIME(),0
    FROM @Menus S WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu M WHERE M.MenuCode=S.MenuCode);

    DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME');
    IF @ProjectID IS NULL THROW 52321,'LAOO_TIME project was not found.',1;

    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @ProjectID,MenuCode,'27',SortOrder,0,SYSDATETIME() FROM @Menus S
    WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu P WHERE P.ProjectID=@ProjectID AND P.MenuCode=S.MenuCode);

    DECLARE @Actions TABLE(ActionCode nvarchar(50),ActionNameTH nvarchar(200),ActionNameEN nvarchar(200));
    INSERT @Actions VALUES(N'VIEW',N'ดูข้อมูล',N'View'),(N'CREATE',N'เพิ่มข้อมูล',N'Create'),
        (N'EDIT',N'แก้ไขข้อมูล',N'Edit'),(N'DELETE',N'ลบข้อมูล',N'Delete');
    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,
        ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @ProjectID,M.MenuCode,M.MenuName,M.FeatureCode,A.ActionCode,A.ActionNameTH,A.ActionNameEN,1,SYSDATETIME()
    FROM @Menus M CROSS JOIN @Actions A
    WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ProjectID AND P.ScreenCode=M.MenuCode AND P.ActionCode=A.ActionCode);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
