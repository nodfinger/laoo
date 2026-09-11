SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDTMScheduleChangeLog',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDTMScheduleChangeLog
 (
  ScheduleChangeLogID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMScheduleChangeLog PRIMARY KEY,
  CompanyID bigint NOT NULL,ScheduleOverrideID bigint NOT NULL,ChangeTypeCode varchar(10) NOT NULL,
  BeforeJson nvarchar(max) NULL,AfterJson nvarchar(max) NULL,Reason nvarchar(1000) NOT NULL,
  ActorUserID bigint NULL,ChangedDate datetime2(3) NOT NULL CONSTRAINT DF_TDTMScheduleChangeLog_Date DEFAULT(sysdatetime()),
  CorrelationID uniqueidentifier NOT NULL CONSTRAINT DF_TDTMScheduleChangeLog_Correlation DEFAULT(newid()),
  CONSTRAINT CK_TDTMScheduleChangeLog_Type CHECK(ChangeTypeCode IN('INSERT','UPDATE','DELETE')),
  CONSTRAINT CK_TDTMScheduleChangeLog_BeforeJson CHECK(BeforeJson IS NULL OR ISJSON(BeforeJson)=1),
  CONSTRAINT CK_TDTMScheduleChangeLog_AfterJson CHECK(AfterJson IS NULL OR ISJSON(AfterJson)=1),
  CONSTRAINT UQ_TDTMScheduleChangeLog_Correlation UNIQUE(CompanyID,CorrelationID)
 );
 CREATE INDEX IX_TDTMScheduleChangeLog_Target ON dbo.TDTMScheduleChangeLog(CompanyID,ScheduleOverrideID,ChangedDate DESC);
END;

EXEC(N'CREATE OR ALTER TRIGGER dbo.TR_TDTMGroupAssignment_NoOverlap ON dbo.TDTMWorkScheduleGroupAssignment AFTER INSERT,UPDATE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.TDTMWorkScheduleGroupAssignment x WITH(UPDLOCK,HOLDLOCK) ON x.CompanyID=i.CompanyID AND x.EmployeeID=i.EmployeeID AND x.WorkScheduleGroupAssignmentID<>i.WorkScheduleGroupAssignmentID AND x.IsActive=1 AND i.IsActive=1 AND x.EffectiveFrom<=ISNULL(i.EffectiveTo,''99991231'') AND i.EffectiveFrom<=ISNULL(x.EffectiveTo,''99991231'')) THROW 52340,N''ช่วงวันที่จัดพนักงานเข้ากลุ่มซ้อนกับรายการเดิม'',1; END;');
EXEC(N'CREATE OR ALTER TRIGGER dbo.TR_TDTMGroupRotation_NoOverlap ON dbo.TDTMGroupShiftRotation AFTER INSERT,UPDATE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.TDTMGroupShiftRotation x WITH(UPDLOCK,HOLDLOCK) ON x.CompanyID=i.CompanyID AND x.WorkScheduleGroupID=i.WorkScheduleGroupID AND x.GroupShiftRotationID<>i.GroupShiftRotationID AND x.IsActive=1 AND i.IsActive=1 AND x.EffectiveFrom<=ISNULL(i.EffectiveTo,''99991231'') AND i.EffectiveFrom<=ISNULL(x.EffectiveTo,''99991231'')) THROW 52341,N''ช่วงวันที่ Rotation ของกลุ่มซ้อนกับรายการเดิม'',1; END;');
EXEC(N'CREATE OR ALTER TRIGGER dbo.TR_TDTMScheduleOverride_Audit ON dbo.TDTMScheduleOverride AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; INSERT dbo.TDTMScheduleChangeLog(CompanyID,ScheduleOverrideID,ChangeTypeCode,BeforeJson,AfterJson,Reason,ActorUserID) SELECT COALESCE(i.CompanyID,d.CompanyID),COALESCE(i.ScheduleOverrideID,d.ScheduleOverrideID),CASE WHEN d.ScheduleOverrideID IS NULL THEN ''INSERT'' WHEN i.ScheduleOverrideID IS NULL THEN ''DELETE'' ELSE ''UPDATE'' END,CASE WHEN d.ScheduleOverrideID IS NULL THEN NULL ELSE(SELECT d.EmployeeID,d.WorkDate,d.IsDayOff,d.ShiftTemplateID,d.WorkBranchID,d.Reason,d.IsActive FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)END,CASE WHEN i.ScheduleOverrideID IS NULL THEN NULL ELSE(SELECT i.EmployeeID,i.WorkDate,i.IsDayOff,i.ShiftTemplateID,i.WorkBranchID,i.Reason,i.IsActive FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)END,COALESCE(i.Reason,d.Reason),COALESCE(i.UpdateBy,i.CreateBy,d.UpdateBy,d.CreateBy) FROM inserted i FULL OUTER JOIN deleted d ON d.ScheduleOverrideID=i.ScheduleOverrideID; END;');
EXEC(N'CREATE OR ALTER TRIGGER dbo.TR_TDTMScheduleChangeLog_Immutable ON dbo.TDTMScheduleChangeLog INSTEAD OF UPDATE,DELETE AS BEGIN THROW 52342,N''ประวัติการปรับตารางห้ามแก้ไขหรือลบ'',1; END;');
