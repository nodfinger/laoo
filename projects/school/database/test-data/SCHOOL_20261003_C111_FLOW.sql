SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Company bigint=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
 DECLARE @User bigint=(SELECT TOP 1 UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
 DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SCHOOL');
 IF @Company IS NULL OR @User IS NULL OR @Project IS NULL THROW 57260,N'School sample prerequisites are missing.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project)
  INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy) VALUES(@Company,@User,@Project,0,1,SYSUTCDATETIME(),@User);
 INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
 SELECT @User,@Project,p.PermissionID,1,1,N'SCHOOL_20261003_C111_FLOW',@User FROM dbo.TDADPermission p
 WHERE p.ProjectID=@Project AND p.IsActive=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission x WHERE x.UserID=@User AND x.ProjectID=@Project AND x.PermissionID=p.PermissionID);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCSchoolLevel WHERE CompanyID=@Company AND LevelCode=N'M3')
  INSERT dbo.TDSCSchoolLevel(CompanyID,LevelCode,LevelName,SortOrder,CreateBy) VALUES(@Company,N'M3',N'มัธยมศึกษาปีที่ 3',30,@User);
 DECLARE @Level bigint=(SELECT LevelID FROM dbo.TDSCSchoolLevel WHERE CompanyID=@Company AND LevelCode=N'M3');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCLearningRound WHERE CompanyID=@Company AND RoundCode=N'NORMAL')
  INSERT dbo.TDSCLearningRound(CompanyID,LevelID,RoundCode,RoundName,CheckInTime,CheckOutTime,LateAfter,CreateBy) VALUES(@Company,@Level,N'NORMAL',N'รอบปกติ','07:30','16:00','08:15',@User);
 DECLARE @Round bigint=(SELECT RoundID FROM dbo.TDSCLearningRound WHERE CompanyID=@Company AND RoundCode=N'NORMAL');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCSubject WHERE CompanyID=@Company AND SubjectCode=N'ENGLISH')
  INSERT dbo.TDSCSubject(CompanyID,SubjectCode,SubjectName,CreateBy) VALUES(@Company,N'ENGLISH',N'ภาษาอังกฤษ',@User);
 DECLARE @Subject bigint=(SELECT SubjectID FROM dbo.TDSCSubject WHERE CompanyID=@Company AND SubjectCode=N'ENGLISH');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCClassroom WHERE CompanyID=@Company AND RoomCode=N'M3-2' AND AcademicYear=2569)
  INSERT dbo.TDSCClassroom(CompanyID,LevelID,RoomCode,RoomName,AcademicYear,CreateBy) VALUES(@Company,@Level,N'M3-2',N'มัธยมศึกษาปีที่ 3/2',2569,@User);
 DECLARE @Room bigint=(SELECT ClassroomID FROM dbo.TDSCClassroom WHERE CompanyID=@Company AND RoomCode=N'M3-2' AND AcademicYear=2569);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCTimetable WHERE CompanyID=@Company AND ClassroomID=@Room AND DayOfWeek=1 AND PeriodNo=1)
  INSERT dbo.TDSCTimetable(CompanyID,ClassroomID,SubjectID,DayOfWeek,PeriodNo,StartTime,EndTime,LearningRoom,TeacherUserID,CreateBy) VALUES(@Company,@Room,@Subject,1,1,'08:30','09:20',N'304',@User,@User);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCStudent WHERE CompanyID=@Company AND StudentCode=N'660214')
  INSERT dbo.TDSCStudent(CompanyID,StudentCode,FirstName,LastName,ClassroomID,RoundID,EnrollmentDate,CreateBy) VALUES(@Company,N'660214',N'ภูมิพัฒน์',N'แสงทอง',@Room,@Round,'2026-05-16',@User);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCStudent WHERE CompanyID=@Company AND StudentCode=N'660229')
  INSERT dbo.TDSCStudent(CompanyID,StudentCode,FirstName,LastName,ClassroomID,RoundID,EnrollmentDate,CreateBy) VALUES(@Company,N'660229',N'พิมพ์ชนก',N'ดีพร้อม',@Room,@Round,'2026-05-16',@User);
 DECLARE @Student bigint=(SELECT StudentID FROM dbo.TDSCStudent WHERE CompanyID=@Company AND StudentCode=N'660214');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCGuardian WHERE CompanyID=@Company AND GuardianCode=N'G-001')
  INSERT dbo.TDSCGuardian(CompanyID,GuardianCode,FullName,Email,Telephone,EmailVerified,CreateBy) VALUES(@Company,N'G-001',N'วราภรณ์ แสงทอง',N'waraporn.school@example.com',N'0812345678',1,@User);
 DECLARE @Guardian bigint=(SELECT GuardianID FROM dbo.TDSCGuardian WHERE CompanyID=@Company AND GuardianCode=N'G-001');
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCStudentGuardian WHERE StudentID=@Student AND GuardianID=@Guardian)
  INSERT dbo.TDSCStudentGuardian(StudentID,GuardianID,RelationshipName,IsPrimary) VALUES(@Student,@Guardian,N'มารดา',1);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCNews WHERE CompanyID=@Company AND Title=N'[SCHOOL_20261003] แจ้งประชุมผู้ปกครอง')
  INSERT dbo.TDSCNews(CompanyID,Title,SummaryText,BodyText,AudienceMode,StatusCode,PublishedAt,CreateBy) VALUES(@Company,N'[SCHOOL_20261003] แจ้งประชุมผู้ปกครอง',N'ประชุมประจำภาคเรียน',N'ขอเชิญผู้ปกครองเข้าร่วมประชุมวันเสาร์ เวลา 09:00 น.',N'ALL',N'PUBLISHED',SYSUTCDATETIME(),@User);
 IF NOT EXISTS(SELECT 1 FROM dbo.TDSCSchoolAttendance WHERE CompanyID=@Company AND StudentID=@Student AND AttendanceDate=CONVERT(date,GETDATE()))
  INSERT dbo.TDSCSchoolAttendance(CompanyID,StudentID,AttendanceDate,CheckInAt,StatusCode,Remark,RecordedBy) VALUES(@Company,@Student,CONVERT(date,GETDATE()),DATEADD(minute,462,CONVERT(datetime2,CONVERT(date,GETDATE()))),N'PRESENT',N'SCHOOL_20261003 sample',@User);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
