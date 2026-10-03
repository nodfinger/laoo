SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'dbo.TDSCSystemSetting',N'U') IS NULL
 CREATE TABLE dbo.TDSCSystemSetting(
  CompanyID bigint NOT NULL PRIMARY KEY,
  AttendanceMode nvarchar(20) NOT NULL CONSTRAINT DF_TDSCSetting_Mode DEFAULT N'SINGLE',
  RequirePeriodAttendance bit NOT NULL CONSTRAINT DF_TDSCSetting_Period DEFAULT 1,
  LateGraceMinutes int NOT NULL CONSTRAINT DF_TDSCSetting_Grace DEFAULT 15,
  TimeZoneID nvarchar(100) NOT NULL CONSTRAINT DF_TDSCSetting_TimeZone DEFAULT N'Asia/Bangkok',
  IsActive bit NOT NULL CONSTRAINT DF_TDSCSetting_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCSetting_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT CK_TDSCSetting_Mode CHECK(AttendanceMode IN(N'SINGLE',N'LEVEL',N'ROUND')),
  CONSTRAINT CK_TDSCSetting_Grace CHECK(LateGraceMinutes BETWEEN 0 AND 180)
 );
 IF OBJECT_ID(N'dbo.TDSCSchoolLevel',N'U') IS NULL
 CREATE TABLE dbo.TDSCSchoolLevel(
  LevelID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,LevelCode nvarchar(30) NOT NULL,
  LevelName nvarchar(150) NOT NULL,SortOrder int NOT NULL CONSTRAINT DF_TDSCLevel_Sort DEFAULT 0,
  IsActive bit NOT NULL CONSTRAINT DF_TDSCLevel_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCLevel_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSCLevel UNIQUE(CompanyID,LevelCode)
 );
 IF OBJECT_ID(N'dbo.TDSCLearningRound',N'U') IS NULL
 CREATE TABLE dbo.TDSCLearningRound(
  RoundID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,LevelID bigint NULL,
  RoundCode nvarchar(30) NOT NULL,RoundName nvarchar(150) NOT NULL,
  CheckInTime time NOT NULL,CheckOutTime time NOT NULL,LateAfter time NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSCRound_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCRound_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSCRound UNIQUE(CompanyID,RoundCode),
  CONSTRAINT FK_TDSCRound_Level FOREIGN KEY(LevelID) REFERENCES dbo.TDSCSchoolLevel(LevelID)
 );
 IF OBJECT_ID(N'dbo.TDSCHoliday',N'U') IS NULL
 CREATE TABLE dbo.TDSCHoliday(
  HolidayID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,HolidayDate date NOT NULL,
  HolidayName nvarchar(200) NOT NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSCHoliday_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCHoliday_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,CONSTRAINT UQ_TDSCHoliday UNIQUE(CompanyID,HolidayDate)
 );
 IF OBJECT_ID(N'dbo.TDSCSubject',N'U') IS NULL
 CREATE TABLE dbo.TDSCSubject(
  SubjectID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,SubjectCode nvarchar(30) NOT NULL,
  SubjectName nvarchar(150) NOT NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSCSubject_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCSubject_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,CONSTRAINT UQ_TDSCSubject UNIQUE(CompanyID,SubjectCode)
 );
 IF OBJECT_ID(N'dbo.TDSCClassroom',N'U') IS NULL
 CREATE TABLE dbo.TDSCClassroom(
  ClassroomID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,LevelID bigint NOT NULL,
  RoomCode nvarchar(30) NOT NULL,RoomName nvarchar(150) NOT NULL,AcademicYear int NOT NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSCClassroom_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCClassroom_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSCClassroom UNIQUE(CompanyID,RoomCode,AcademicYear),
  CONSTRAINT FK_TDSCClassroom_Level FOREIGN KEY(LevelID) REFERENCES dbo.TDSCSchoolLevel(LevelID)
 );
 IF OBJECT_ID(N'dbo.TDSCTimetable',N'U') IS NULL
 CREATE TABLE dbo.TDSCTimetable(
  TimetableID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,ClassroomID bigint NOT NULL,
  SubjectID bigint NOT NULL,DayOfWeek tinyint NOT NULL,PeriodNo int NOT NULL,
  StartTime time NOT NULL,EndTime time NOT NULL,LearningRoom nvarchar(100) NULL,
  TeacherUserID bigint NULL,RequireAttendance bit NOT NULL CONSTRAINT DF_TDSCTimetable_Require DEFAULT 1,
  IsActive bit NOT NULL CONSTRAINT DF_TDSCTimetable_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCTimetable_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSCTimetable UNIQUE(CompanyID,ClassroomID,DayOfWeek,PeriodNo),
  CONSTRAINT CK_TDSCTimetable_Day CHECK(DayOfWeek BETWEEN 1 AND 7),
  CONSTRAINT FK_TDSCTimetable_Classroom FOREIGN KEY(ClassroomID) REFERENCES dbo.TDSCClassroom(ClassroomID),
  CONSTRAINT FK_TDSCTimetable_Subject FOREIGN KEY(SubjectID) REFERENCES dbo.TDSCSubject(SubjectID)
 );
 IF OBJECT_ID(N'dbo.TDSCStudent',N'U') IS NULL
 CREATE TABLE dbo.TDSCStudent(
  StudentID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,StudentCode nvarchar(30) NOT NULL,
  FirstName nvarchar(100) NOT NULL,LastName nvarchar(100) NOT NULL,ClassroomID bigint NOT NULL,
  RoundID bigint NULL,EnrollmentDate date NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSCStudent_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCStudent_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSCStudent UNIQUE(CompanyID,StudentCode),
  CONSTRAINT FK_TDSCStudent_Classroom FOREIGN KEY(ClassroomID) REFERENCES dbo.TDSCClassroom(ClassroomID),
  CONSTRAINT FK_TDSCStudent_Round FOREIGN KEY(RoundID) REFERENCES dbo.TDSCLearningRound(RoundID)
 );
 IF OBJECT_ID(N'dbo.TDSCGuardian',N'U') IS NULL
 CREATE TABLE dbo.TDSCGuardian(
  GuardianID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,GuardianCode nvarchar(30) NOT NULL,
  FullName nvarchar(200) NOT NULL,Email nvarchar(320) NOT NULL,Telephone nvarchar(50) NULL,
  PasswordHash nvarchar(500) NULL,EmailVerified bit NOT NULL CONSTRAINT DF_TDSCGuardian_Verified DEFAULT 0,
  FailedLoginCount int NOT NULL CONSTRAINT DF_TDSCGuardian_Failed DEFAULT 0,LockedUntil datetime2 NULL,
  IsActive bit NOT NULL CONSTRAINT DF_TDSCGuardian_Active DEFAULT 1,
  CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCGuardian_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSCGuardian_Code UNIQUE(CompanyID,GuardianCode),
  CONSTRAINT UQ_TDSCGuardian_Email UNIQUE(CompanyID,Email)
 );
 IF OBJECT_ID(N'dbo.TDSCStudentGuardian',N'U') IS NULL
 CREATE TABLE dbo.TDSCStudentGuardian(
  StudentID bigint NOT NULL,GuardianID bigint NOT NULL,RelationshipName nvarchar(100) NOT NULL,
  IsPrimary bit NOT NULL CONSTRAINT DF_TDSCStudentGuardian_Primary DEFAULT 0,
  CanReceiveNews bit NOT NULL CONSTRAINT DF_TDSCStudentGuardian_News DEFAULT 1,
  CanViewAttendance bit NOT NULL CONSTRAINT DF_TDSCStudentGuardian_View DEFAULT 1,
  CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCStudentGuardian_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_TDSCStudentGuardian PRIMARY KEY(StudentID,GuardianID),
  CONSTRAINT FK_TDSCStudentGuardian_Student FOREIGN KEY(StudentID) REFERENCES dbo.TDSCStudent(StudentID),
  CONSTRAINT FK_TDSCStudentGuardian_Guardian FOREIGN KEY(GuardianID) REFERENCES dbo.TDSCGuardian(GuardianID)
 );
 IF OBJECT_ID(N'dbo.TDSCSchoolAttendance',N'U') IS NULL
 CREATE TABLE dbo.TDSCSchoolAttendance(
  AttendanceID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,StudentID bigint NOT NULL,
  AttendanceDate date NOT NULL,CheckInAt datetime2 NULL,CheckOutAt datetime2 NULL,
  StatusCode nvarchar(20) NOT NULL,Remark nvarchar(500) NULL,RecordedBy bigint NOT NULL,
  CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCSchoolAttendance_Create DEFAULT SYSUTCDATETIME(),
  UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDSCSchoolAttendance UNIQUE(CompanyID,StudentID,AttendanceDate),
  CONSTRAINT CK_TDSCSchoolAttendance_Status CHECK(StatusCode IN(N'PRESENT',N'LATE',N'LEAVE',N'ABSENT')),
  CONSTRAINT FK_TDSCSchoolAttendance_Student FOREIGN KEY(StudentID) REFERENCES dbo.TDSCStudent(StudentID)
 );
 IF OBJECT_ID(N'dbo.TDSCPeriodAttendance',N'U') IS NULL
 CREATE TABLE dbo.TDSCPeriodAttendance(
  PeriodAttendanceID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,TimetableID bigint NOT NULL,
  AttendanceDate date NOT NULL,RecordedBy bigint NOT NULL,RecordedAt datetime2 NOT NULL CONSTRAINT DF_TDSCPeriodAttendance_Recorded DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_TDSCPeriodAttendance UNIQUE(CompanyID,TimetableID,AttendanceDate),
  CONSTRAINT FK_TDSCPeriodAttendance_Timetable FOREIGN KEY(TimetableID) REFERENCES dbo.TDSCTimetable(TimetableID)
 );
 IF OBJECT_ID(N'dbo.TDSCPeriodAttendanceDetail',N'U') IS NULL
 CREATE TABLE dbo.TDSCPeriodAttendanceDetail(
  PeriodAttendanceID bigint NOT NULL,StudentID bigint NOT NULL,StatusCode nvarchar(20) NOT NULL,
  Remark nvarchar(500) NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCPeriodDetail_Create DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_TDSCPeriodAttendanceDetail PRIMARY KEY(PeriodAttendanceID,StudentID),
  CONSTRAINT CK_TDSCPeriodDetail_Status CHECK(StatusCode IN(N'PRESENT',N'LATE',N'LEAVE',N'ABSENT')),
  CONSTRAINT FK_TDSCPeriodDetail_Header FOREIGN KEY(PeriodAttendanceID) REFERENCES dbo.TDSCPeriodAttendance(PeriodAttendanceID) ON DELETE CASCADE,
  CONSTRAINT FK_TDSCPeriodDetail_Student FOREIGN KEY(StudentID) REFERENCES dbo.TDSCStudent(StudentID)
 );
 IF OBJECT_ID(N'dbo.TDSCNews',N'U') IS NULL
 CREATE TABLE dbo.TDSCNews(
  NewsID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,Title nvarchar(250) NOT NULL,
  SummaryText nvarchar(1000) NULL,BodyText nvarchar(max) NOT NULL,AudienceMode nvarchar(20) NOT NULL,
  StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDSCNews_Status DEFAULT N'DRAFT',
  PublishedAt datetime2 NULL,IsActive bit NOT NULL CONSTRAINT DF_TDSCNews_Active DEFAULT 1,
  CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCNews_Create DEFAULT SYSUTCDATETIME(),
  UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT CK_TDSCNews_Audience CHECK(AudienceMode IN(N'ALL',N'LEVEL',N'CLASSROOM',N'GUARDIAN')),
  CONSTRAINT CK_TDSCNews_Status CHECK(StatusCode IN(N'DRAFT',N'PUBLISHED',N'CANCELLED'))
 );
 IF OBJECT_ID(N'dbo.TDSCNewsAudience',N'U') IS NULL
 CREATE TABLE dbo.TDSCNewsAudience(
  NewsID bigint NOT NULL,AudienceType nvarchar(20) NOT NULL,AudienceID bigint NOT NULL,
  CONSTRAINT PK_TDSCNewsAudience PRIMARY KEY(NewsID,AudienceType,AudienceID),
  CONSTRAINT FK_TDSCNewsAudience_News FOREIGN KEY(NewsID) REFERENCES dbo.TDSCNews(NewsID) ON DELETE CASCADE
 );
 IF OBJECT_ID(N'dbo.TDSCAudit',N'U') IS NULL
 CREATE TABLE dbo.TDSCAudit(
  AuditID bigint IDENTITY PRIMARY KEY,CompanyID bigint NOT NULL,EntityType nvarchar(50) NOT NULL,
  EntityID bigint NOT NULL,ActionCode nvarchar(30) NOT NULL,DetailText nvarchar(1000) NULL,
  UserID bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDSCAudit_Create DEFAULT SYSUTCDATETIME()
 );
 CREATE INDEX IX_TDSCAudit_CompanyDate ON dbo.TDSCAudit(CompanyID,CreateDate DESC);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
