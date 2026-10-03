using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooSchoolModule.Controllers;

[ApiController,Authorize,Route("api/company/school")]
public sealed class SchoolController(IConfiguration configuration):ControllerBase
{
 static readonly string[] Menus=["52001","52002","52003","52004","52005","52006","52007","52008","52009","52010","52011","52012","52013","52014"];

 [HttpGet("actions/{menu}")]
 public async Task<IActionResult> Actions(string menu,CancellationToken token)
 {
  if(!Menus.Contains(menu)||!Scope(out _,out _))return Forbid();
  await using var db=await Open(token);if(!await Can(db,menu,"VIEW",token))return Forbid();
  var names=new[]{"CREATE","EDIT","DELETE","PUBLISH","EXPORT"};
  var result=new Dictionary<string,bool>();foreach(var name in names)result[name.ToLowerInvariant()]=await Can(db,menu,name,token);
  return Ok(result);
 }

 [HttpGet("settings")]
 public async Task<IActionResult> Settings(CancellationToken token)
 {
  if(!Scope(out var company,out var user))return Forbid();
  await using var db=await Open(token);if(!await Can(db,"52001","VIEW",token))return Forbid();
  await Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDSCSystemSetting WHERE CompanyID=@company) INSERT dbo.TDSCSystemSetting(CompanyID,CreateBy) VALUES(@company,@user)",token,("@company",company),("@user",user));
  return Ok((await Query(db,"SELECT AttendanceMode attendanceMode,RequirePeriodAttendance requirePeriodAttendance,LateGraceMinutes lateGraceMinutes,IsActive active FROM dbo.TDSCSystemSetting WHERE CompanyID=@company",token,("@company",company))).Single());
 }
 [HttpPut("settings")]
 public async Task<IActionResult> Settings(SchoolSettings request,CancellationToken token)
 {
  if(request.AttendanceMode is not ("SINGLE" or "LEVEL" or "ROUND")||request.LateGraceMinutes is <0 or >180)
   return Bad("ค่าตั้งค่าไม่ถูกต้อง","กำหนดนาทีสายระหว่าง 0-180 นาที");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);
  if(!await Can(db,"52001","EDIT",token))return Forbid();
  await Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDSCSystemSetting WHERE CompanyID=@company) INSERT dbo.TDSCSystemSetting(CompanyID,CreateBy) VALUES(@company,@user);UPDATE dbo.TDSCSystemSetting SET AttendanceMode=@mode,RequirePeriodAttendance=@period,LateGraceMinutes=@grace,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company",token,("@company",company),("@user",user),("@mode",request.AttendanceMode),("@period",request.RequirePeriodAttendance),("@grace",request.LateGraceMinutes),("@active",request.Active));
  return NoContent();
 }
 [HttpGet("dashboard")]
 public async Task<IActionResult> Dashboard(DateTime? date,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);
  if(!await Can(db,"52013","VIEW",token))return Forbid();var day=(date??DateTime.Today).Date;
  var sql="SELECT COUNT(*) total,SUM(CASE WHEN a.StatusCode IN(N'PRESENT',N'LATE') THEN 1 ELSE 0 END) present,SUM(CASE WHEN a.StatusCode=N'LATE' THEN 1 ELSE 0 END) late,SUM(CASE WHEN a.StatusCode=N'ABSENT' THEN 1 ELSE 0 END) absent FROM dbo.TDSCStudent s LEFT JOIN dbo.TDSCSchoolAttendance a ON a.CompanyID=s.CompanyID AND a.StudentID=s.StudentID AND a.AttendanceDate=@day WHERE s.CompanyID=@company AND s.IsActive=1";
  return Ok(new{date=day,summary=(await Query(db,sql,token,("@company",company),("@day",day))).Single()});
 }
 [HttpGet("masters/{type}")]
 public async Task<IActionResult> Masters(string type,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();var spec=MasterSpec(type);if(spec is null)return NotFound();
  await using var db=await Open(token);if(!await Can(db,spec.Value.Menu,"VIEW",token))return Forbid();
  var sql=spec.Value.Type switch{
   "level"=>"SELECT LevelID id,LevelCode code,LevelName name,SortOrder sortOrder,IsActive active FROM dbo.TDSCSchoolLevel WHERE CompanyID=@company ORDER BY SortOrder,LevelName",
   "round"=>"SELECT RoundID id,RoundCode code,RoundName name,CheckInTime checkInTime,CheckOutTime checkOutTime,LateAfter lateAfter,IsActive active FROM dbo.TDSCLearningRound WHERE CompanyID=@company ORDER BY RoundName",
   "holiday"=>"SELECT HolidayID id,CONVERT(nvarchar(10),HolidayDate,23) code,HolidayName name,IsActive active FROM dbo.TDSCHoliday WHERE CompanyID=@company ORDER BY HolidayDate DESC",
   "subject"=>"SELECT SubjectID id,SubjectCode code,SubjectName name,IsActive active FROM dbo.TDSCSubject WHERE CompanyID=@company ORDER BY SubjectName",
   _=>"SELECT ClassroomID id,RoomCode code,RoomName name,AcademicYear academicYear,IsActive active FROM dbo.TDSCClassroom WHERE CompanyID=@company ORDER BY AcademicYear DESC,RoomName"};
  return Ok(await Query(db,sql,token,("@company",company)));
 }
 [HttpPost("masters/{type}")]
 public Task<IActionResult> SaveMaster(string type,SchoolMaster request,CancellationToken token)=>SaveMaster(type,null,request,"CREATE",token);
 [HttpPut("masters/{type}/{id:long}")]
 public Task<IActionResult> SaveMaster(string type,long id,SchoolMaster request,CancellationToken token)=>SaveMaster(type,id,request,"EDIT",token);
 [HttpDelete("masters/{type}/{id:long}")]
 public async Task<IActionResult> DeleteMaster(string type,long id,CancellationToken token)
 {
  var spec=MasterSpec(type);var target=MasterDeleteSpec(type);
  if(spec is null||target is null)return NotFound();
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);
  if(!await Can(db,spec.Value.Menu,"DELETE",token))return Forbid();
  try{
   var count=await Execute(db,$"DELETE dbo.{target.Value.Table} WHERE CompanyID=@company AND {target.Value.Id}=@id",token,("@company",company),("@id",id));
   return count>0?NoContent():NotFound();
  }catch(SqlException e)when(e.Number==547){return Conflict(new{message="ไม่สามารถลบรายการที่ถูกใช้งานแล้ว",description="กรุณาปิดสถานะแทนการลบ"});}
 }
 async Task<IActionResult> SaveMaster(string type,long? id,SchoolMaster request,string action,CancellationToken token)
 {
  var spec=MasterSpec(type);var code=Clean(request.Code);var name=Clean(request.Name);
  if(spec is null||code is null||name is null)return Bad("ข้อมูล Master ไม่ครบ","ระบุรหัสและชื่อรายการ");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);
  if(!await Can(db,spec.Value.Menu,action,token))return Forbid();
  var sql=MasterSaveSql(spec.Value.Type,id.HasValue);
  try{var saved=await Scalar<long>(db,null,sql,token,("@id",id),("@company",company),("@code",code),("@name",name),("@parent",request.ParentId),("@date",request.Date),("@start",request.StartTime),("@end",request.EndTime),("@late",request.LateAfter),("@year",request.AcademicYear??DateTime.Today.Year+543),("@sort",request.SortOrder),("@active",request.Active),("@user",user));return saved>0?Ok(new{id=saved}):NotFound();}
  catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสหรือวันที่ซ้ำ",description="ใช้ค่าอื่นภายในโรงเรียนเดียวกัน"});}
 }
 [HttpGet("students")]
 public async Task<IActionResult> Students(CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52006","VIEW",token))return Forbid();
  var sql="SELECT s.StudentID id,s.StudentCode code,CONCAT(s.FirstName,N' ',s.LastName) name,c.RoomName classroom,r.RoundName roundName,s.IsActive active FROM dbo.TDSCStudent s JOIN dbo.TDSCClassroom c ON c.ClassroomID=s.ClassroomID LEFT JOIN dbo.TDSCLearningRound r ON r.RoundID=s.RoundID WHERE s.CompanyID=@company ORDER BY c.RoomName,s.StudentCode";
  return Ok(await Query(db,sql,token,("@company",company)));
 }
 [HttpGet("academics")]
 public async Task<IActionResult> Academics(CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52005","VIEW",token))return Forbid();
  var subjects=await Query(db,"SELECT SubjectID id,SubjectCode code,SubjectName name,IsActive active FROM dbo.TDSCSubject WHERE CompanyID=@company ORDER BY SubjectName",token,("@company",company));
  var rooms=await Query(db,"SELECT c.ClassroomID id,c.RoomCode code,c.RoomName name,c.LevelID levelId,l.LevelName levelName,c.AcademicYear academicYear,c.IsActive active FROM dbo.TDSCClassroom c JOIN dbo.TDSCSchoolLevel l ON l.LevelID=c.LevelID WHERE c.CompanyID=@company ORDER BY c.AcademicYear DESC,c.RoomName",token,("@company",company));
  var tables=await Query(db,"SELECT t.TimetableID id,t.ClassroomID classroomId,t.SubjectID subjectId,t.DayOfWeek dayOfWeek,t.PeriodNo periodNo,t.StartTime startTime,t.EndTime endTime,t.LearningRoom learningRoom,t.IsActive active,c.RoomName classroom,s.SubjectName subject FROM dbo.TDSCTimetable t JOIN dbo.TDSCClassroom c ON c.ClassroomID=t.ClassroomID JOIN dbo.TDSCSubject s ON s.SubjectID=t.SubjectID WHERE t.CompanyID=@company ORDER BY c.RoomName,t.DayOfWeek,t.PeriodNo",token,("@company",company));
  return Ok(new{subjects,classrooms=rooms,timetables=tables});
 }
 [HttpPost("timetables")]
 public Task<IActionResult> Timetable(TimetableRequest request,CancellationToken token)=>SaveTimetable(null,request,"CREATE",token);
 [HttpPut("timetables/{id:long}")]
 public Task<IActionResult> Timetable(long id,TimetableRequest request,CancellationToken token)=>SaveTimetable(id,request,"EDIT",token);
 async Task<IActionResult> SaveTimetable(long? id,TimetableRequest request,string action,CancellationToken token)
 {
  if(request.ClassroomId<=0||request.SubjectId<=0||request.DayOfWeek is <1 or >7||request.PeriodNo<=0||request.StartTime>=request.EndTime)return Bad("ข้อมูลตารางเรียนไม่ถูกต้อง","ตรวจห้องเรียน วิชา วัน คาบ และช่วงเวลา");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"52005",action,token))return Forbid();
  var sql=id.HasValue
   ?"UPDATE t SET ClassroomID=@room,SubjectID=@subject,DayOfWeek=@day,PeriodNo=@period,StartTime=@start,EndTime=@end,LearningRoom=@learning,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.TimetableID FROM dbo.TDSCTimetable t JOIN dbo.TDSCClassroom c ON c.ClassroomID=@room AND c.CompanyID=@company JOIN dbo.TDSCSubject s ON s.SubjectID=@subject AND s.CompanyID=@company WHERE t.CompanyID=@company AND t.TimetableID=@id"
   :"INSERT dbo.TDSCTimetable(CompanyID,ClassroomID,SubjectID,DayOfWeek,PeriodNo,StartTime,EndTime,LearningRoom,IsActive,CreateBy) OUTPUT INSERTED.TimetableID SELECT @company,@room,@subject,@day,@period,@start,@end,@learning,@active,@user WHERE EXISTS(SELECT 1 FROM dbo.TDSCClassroom WHERE CompanyID=@company AND ClassroomID=@room) AND EXISTS(SELECT 1 FROM dbo.TDSCSubject WHERE CompanyID=@company AND SubjectID=@subject)";
  try{var saved=await Scalar<long>(db,null,sql,token,("@id",id),("@company",company),("@room",request.ClassroomId),("@subject",request.SubjectId),("@day",request.DayOfWeek),("@period",request.PeriodNo),("@start",request.StartTime),("@end",request.EndTime),("@learning",Clean(request.LearningRoom)),("@active",request.Active),("@user",user));return saved>0?Ok(new{id=saved}):Bad("ไม่พบข้อมูลอ้างอิง","ห้องเรียนหรือวิชาต้องอยู่ในโรงเรียนเดียวกัน");}
  catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="ตารางเรียนซ้ำ",description="วันและคาบของห้องเรียนต้องไม่ซ้ำ"});}
 }
 [HttpDelete("timetables/{id:long}")]
 public async Task<IActionResult> DeleteTimetable(long id,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52005","DELETE",token))return Forbid();
  try{var count=await Execute(db,"DELETE dbo.TDSCTimetable WHERE CompanyID=@company AND TimetableID=@id",token,("@company",company),("@id",id));return count>0?NoContent():NotFound();}
  catch(SqlException e)when(e.Number==547){return Conflict(new{message="ไม่สามารถลบตารางที่มีประวัติเช็กชื่อ",description="กรุณาปิดสถานะแทนการลบ"});}
 }
 [HttpGet("guardians")]
 public async Task<IActionResult> Guardians(CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52007","VIEW",token))return Forbid();
  var sql="SELECT g.GuardianID id,g.GuardianCode code,g.FullName name,g.Email,g.Telephone,g.EmailVerified emailVerified,g.IsActive active,(SELECT COUNT(*) FROM dbo.TDSCStudentGuardian x WHERE x.GuardianID=g.GuardianID) childCount,(SELECT STRING_AGG(CONVERT(nvarchar(20),x.StudentID),N',') FROM dbo.TDSCStudentGuardian x WHERE x.GuardianID=g.GuardianID) studentIds FROM dbo.TDSCGuardian g WHERE g.CompanyID=@company ORDER BY g.FullName";
  return Ok(await Query(db,sql,token,("@company",company)));
 }
 [HttpPost("students")] public Task<IActionResult> Student(StudentRequest r,CancellationToken t)=>SaveStudent(null,r,"CREATE",t);
 [HttpPut("students/{id:long}")] public Task<IActionResult> Student(long id,StudentRequest r,CancellationToken t)=>SaveStudent(id,r,"EDIT",t);
 [HttpDelete("students/{id:long}")]
 public async Task<IActionResult> DeleteStudent(long id,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);
  if(!await Can(db,"52006","DELETE",token))return Forbid();
  await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);try{
   await Execute(db,tx,"DELETE d FROM dbo.TDSCPeriodAttendanceDetail d JOIN dbo.TDSCPeriodAttendance h ON h.PeriodAttendanceID=d.PeriodAttendanceID WHERE h.CompanyID=@company AND d.StudentID=@id",token,("@company",company),("@id",id));
   await Execute(db,tx,"DELETE dbo.TDSCSchoolAttendance WHERE CompanyID=@company AND StudentID=@id",token,("@company",company),("@id",id));
   await Execute(db,tx,"DELETE sg FROM dbo.TDSCStudentGuardian sg JOIN dbo.TDSCStudent s ON s.StudentID=sg.StudentID WHERE s.CompanyID=@company AND sg.StudentID=@id",token,("@company",company),("@id",id));
   var count=await Execute(db,tx,"DELETE dbo.TDSCStudent WHERE CompanyID=@company AND StudentID=@id",token,("@company",company),("@id",id));
   await tx.CommitAsync(token);return count>0?NoContent():NotFound();
  }catch{await tx.RollbackAsync(token);throw;}
 }
 async Task<IActionResult> SaveStudent(long? id,StudentRequest request,string action,CancellationToken token)
 {
  if(Clean(request.Code) is null||Clean(request.FirstName) is null||Clean(request.LastName) is null||request.ClassroomId<=0)return Bad("ข้อมูลนักเรียนไม่ครบ","ระบุรหัส ชื่อ นามสกุล และห้องเรียน");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"52006",action,token))return Forbid();
  var sql=id.HasValue?"UPDATE dbo.TDSCStudent SET StudentCode=@code,FirstName=@first,LastName=@last,ClassroomID=@room,RoundID=@round,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.StudentID WHERE CompanyID=@company AND StudentID=@id":"INSERT dbo.TDSCStudent(CompanyID,StudentCode,FirstName,LastName,ClassroomID,RoundID,IsActive,CreateBy) OUTPUT INSERTED.StudentID VALUES(@company,@code,@first,@last,@room,@round,@active,@user)";
  try{var saved=await Scalar<long>(db,null,sql,token,("@id",id),("@company",company),("@code",request.Code.Trim()),("@first",request.FirstName.Trim()),("@last",request.LastName.Trim()),("@room",request.ClassroomId),("@round",request.RoundId),("@active",request.Active),("@user",user));return saved>0?Ok(new{id=saved}):NotFound();}
  catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสนักเรียนซ้ำ",description="ใช้รหัสอื่นในโรงเรียนเดียวกัน"});}
 }
 [HttpPost("guardians")] public Task<IActionResult> Guardian(GuardianRequest r,CancellationToken t)=>SaveGuardian(null,r,"CREATE",t);
 [HttpPut("guardians/{id:long}")] public Task<IActionResult> Guardian(long id,GuardianRequest r,CancellationToken t)=>SaveGuardian(id,r,"EDIT",t);
 [HttpDelete("guardians/{id:long}")]
 public async Task<IActionResult> DeleteGuardian(long id,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);
  if(!await Can(db,"52007","DELETE",token))return Forbid();
  await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);try{
   await Execute(db,tx,"DELETE sg FROM dbo.TDSCStudentGuardian sg JOIN dbo.TDSCGuardian g ON g.GuardianID=sg.GuardianID WHERE g.CompanyID=@company AND sg.GuardianID=@id",token,("@company",company),("@id",id));
   var count=await Execute(db,tx,"DELETE dbo.TDSCGuardian WHERE CompanyID=@company AND GuardianID=@id",token,("@company",company),("@id",id));
   await tx.CommitAsync(token);return count>0?NoContent():NotFound();
  }catch{await tx.RollbackAsync(token);throw;}
 }
 async Task<IActionResult> SaveGuardian(long? id,GuardianRequest request,string action,CancellationToken token)
 {
  if(Clean(request.Code) is null||Clean(request.FullName) is null||Clean(request.Email) is null)return Bad("ข้อมูลผู้ปกครองไม่ครบ","ระบุรหัส ชื่อ และ Email สำหรับ Login");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"52007",action,token))return Forbid();
  var sql=id.HasValue?"UPDATE dbo.TDSCGuardian SET GuardianCode=@code,FullName=@name,Email=@email,Telephone=@phone,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.GuardianID WHERE CompanyID=@company AND GuardianID=@id":"INSERT dbo.TDSCGuardian(CompanyID,GuardianCode,FullName,Email,Telephone,IsActive,CreateBy) OUTPUT INSERTED.GuardianID VALUES(@company,@code,@name,@email,@phone,@active,@user)";
  await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);try{
   var saved=await Scalar<long>(db,tx,sql,token,("@id",id),("@company",company),("@code",request.Code.Trim()),("@name",request.FullName.Trim()),("@email",request.Email.Trim().ToLowerInvariant()),("@phone",Clean(request.Telephone)),("@active",request.Active),("@user",user));
   if(saved==0){await tx.RollbackAsync(token);return NotFound();}
   if(request.StudentIds is not null){
    var unique=request.StudentIds.Where(x=>x>0).Distinct().ToList();
    foreach(var student in unique){
     var exists=await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDSCStudent WHERE CompanyID=@company AND StudentID=@student AND IsActive=1",token,("@company",company),("@student",student));
     if(exists!=1){await tx.RollbackAsync(token);return Bad("ข้อมูลนักเรียนไม่ถูกต้อง","นักเรียนต้องอยู่ในโรงเรียนเดียวกันและยังใช้งาน");}
    }
    await Execute(db,tx,"DELETE dbo.TDSCStudentGuardian WHERE GuardianID=@guardian",token,("@guardian",saved));
    foreach(var student in unique)await Execute(db,tx,"INSERT dbo.TDSCStudentGuardian(StudentID,GuardianID,RelationshipName,IsPrimary,CanReceiveNews,CanViewAttendance) VALUES(@student,@guardian,N'ผู้ปกครอง',0,1,1)",token,("@student",student),("@guardian",saved));
   }
   await tx.CommitAsync(token);return Ok(new{id=saved});
  }
  catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสหรือ Email ซ้ำ",description="ใช้ข้อมูลอื่นในโรงเรียนเดียวกัน"});}
 }
 [HttpGet("attendance")]
 public async Task<IActionResult> Attendance(DateTime? date,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52008","VIEW",token))return Forbid();var day=(date??DateTime.Today).Date;
  var sql="SELECT s.StudentID id,s.StudentCode code,CONCAT(s.FirstName,N' ',s.LastName) name,c.RoomName classroom,a.CheckInAt checkInAt,a.CheckOutAt checkOutAt,COALESCE(a.StatusCode,N'ABSENT') status,a.Remark remark FROM dbo.TDSCStudent s JOIN dbo.TDSCClassroom c ON c.ClassroomID=s.ClassroomID LEFT JOIN dbo.TDSCSchoolAttendance a ON a.CompanyID=s.CompanyID AND a.StudentID=s.StudentID AND a.AttendanceDate=@day WHERE s.CompanyID=@company AND s.IsActive=1 ORDER BY c.RoomName,s.StudentCode";
  return Ok(new{date=day,items=await Query(db,sql,token,("@company",company),("@day",day))});
 }
 [HttpPost("attendance")]
 public async Task<IActionResult> Attendance(SchoolAttendanceRequest request,CancellationToken token)
 {
  if(request.StudentId<=0||request.Status is not ("PRESENT" or "LATE" or "LEAVE" or "ABSENT"))return Bad("ข้อมูลลงเวลาไม่ถูกต้อง","เลือกนักเรียนและสถานะที่กำหนด");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"52008","CREATE",token)&&!await Can(db,"52008","EDIT",token))return Forbid();var day=request.Date.Date;
  var sql="MERGE dbo.TDSCSchoolAttendance AS t USING(SELECT @company CompanyID,@student StudentID,@day AttendanceDate)s ON t.CompanyID=s.CompanyID AND t.StudentID=s.StudentID AND t.AttendanceDate=s.AttendanceDate WHEN MATCHED THEN UPDATE SET CheckInAt=COALESCE(@checkIn,t.CheckInAt),CheckOutAt=COALESCE(@checkOut,t.CheckOutAt),StatusCode=@status,Remark=@remark,RecordedBy=@user,UpdateDate=SYSUTCDATETIME() WHEN NOT MATCHED THEN INSERT(CompanyID,StudentID,AttendanceDate,CheckInAt,CheckOutAt,StatusCode,Remark,RecordedBy) VALUES(@company,@student,@day,@checkIn,@checkOut,@status,@remark,@user);";
  await Execute(db,sql,token,("@company",company),("@student",request.StudentId),("@day",day),("@checkIn",request.CheckInAt),("@checkOut",request.CheckOutAt),("@status",request.Status),("@remark",Clean(request.Remark)),("@user",user));return NoContent();
 }
 [HttpGet("roll-call")]
 public async Task<IActionResult> RollCall(long timetableId,DateTime? date,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52009","VIEW",token))return Forbid();var day=(date??DateTime.Today).Date;
  var lessons=await Query(db,"SELECT t.TimetableID id,t.ClassroomID classroomId,t.PeriodNo periodNo,t.StartTime startTime,t.EndTime endTime,t.LearningRoom,s.SubjectName subjectName,c.RoomName classroom FROM dbo.TDSCTimetable t JOIN dbo.TDSCSubject s ON s.SubjectID=t.SubjectID JOIN dbo.TDSCClassroom c ON c.ClassroomID=t.ClassroomID WHERE t.CompanyID=@company AND t.TimetableID=@id",token,("@company",company),("@id",timetableId));if(lessons.Count==0)return NotFound();
  var sql="SELECT st.StudentID id,st.StudentCode code,CONCAT(st.FirstName,N' ',st.LastName) name,COALESCE(d.StatusCode,N'PRESENT') status,d.Remark remark FROM dbo.TDSCStudent st LEFT JOIN dbo.TDSCPeriodAttendance h ON h.CompanyID=st.CompanyID AND h.TimetableID=@id AND h.AttendanceDate=@day LEFT JOIN dbo.TDSCPeriodAttendanceDetail d ON d.PeriodAttendanceID=h.PeriodAttendanceID AND d.StudentID=st.StudentID WHERE st.CompanyID=@company AND st.ClassroomID=@room AND st.IsActive=1 ORDER BY st.StudentCode";
  return Ok(new{lesson=lessons[0],date=day,students=await Query(db,sql,token,("@company",company),("@id",timetableId),("@day",day),("@room",lessons[0]["classroomId"]))});
 }
 [HttpPost("roll-call")]
 public async Task<IActionResult> RollCall(PeriodAttendanceRequest request,CancellationToken token)
 {
  if(request.TimetableId<=0||request.Students.Count==0||request.Students.Any(x=>x.Status is not ("PRESENT" or "LATE" or "LEAVE" or "ABSENT")))return Bad("ข้อมูลเช็กชื่อไม่ถูกต้อง","เลือกรายวิชาและระบุสถานะนักเรียนทุกคน");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"52009","CREATE",token)&&!await Can(db,"52009","EDIT",token))return Forbid();
  await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);try{
   var header=await Scalar<long>(db,tx,"SELECT PeriodAttendanceID FROM dbo.TDSCPeriodAttendance WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND TimetableID=@table AND AttendanceDate=@day",token,("@company",company),("@table",request.TimetableId),("@day",request.Date.Date));
   if(header==0)header=await Scalar<long>(db,tx,"INSERT dbo.TDSCPeriodAttendance(CompanyID,TimetableID,AttendanceDate,RecordedBy) OUTPUT INSERTED.PeriodAttendanceID VALUES(@company,@table,@day,@user)",token,("@company",company),("@table",request.TimetableId),("@day",request.Date.Date),("@user",user));
   await Execute(db,tx,"DELETE dbo.TDSCPeriodAttendanceDetail WHERE PeriodAttendanceID=@id",token,("@id",header));
   foreach(var row in request.Students)await Execute(db,tx,"INSERT dbo.TDSCPeriodAttendanceDetail(PeriodAttendanceID,StudentID,StatusCode,Remark) VALUES(@id,@student,@status,@remark)",token,("@id",header),("@student",row.StudentId),("@status",row.Status),("@remark",Clean(row.Remark)));
   await tx.CommitAsync(token);return Ok(new{id=header});
  }catch{await tx.RollbackAsync(token);throw;}
 }
 [HttpGet("news")]
 public async Task<IActionResult> News(CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52010","VIEW",token))return Forbid();
  return Ok(await Query(db,"SELECT NewsID id,Title title,SummaryText summary,BodyText body,AudienceMode audienceMode,StatusCode status,PublishedAt publishedAt,CreateDate createDate FROM dbo.TDSCNews WHERE CompanyID=@company AND IsActive=1 ORDER BY CreateDate DESC",token,("@company",company)));
 }
 [HttpPost("news")]
 public Task<IActionResult> News(NewsRequest request,CancellationToken token)=>SaveNews(null,request,"CREATE",token);
 [HttpPut("news/{id:long}")]
 public Task<IActionResult> News(long id,NewsRequest request,CancellationToken token)=>SaveNews(id,request,"EDIT",token);
 async Task<IActionResult> SaveNews(long? id,NewsRequest request,string action,CancellationToken token)
 {
  if(Clean(request.Title) is null||Clean(request.Body) is null||request.AudienceMode is not ("ALL" or "LEVEL" or "CLASSROOM" or "GUARDIAN"))return Bad("ข้อมูลข่าวสารไม่ครบ","ระบุหัวข้อ เนื้อหา และกลุ่มผู้รับ");
  if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"52010",action,token))return Forbid();var status=request.Publish?"PUBLISHED":"DRAFT";if(request.Publish&&!await Can(db,"52010","PUBLISH",token))return Forbid();
  var saved=id.HasValue
   ?await Scalar<long>(db,null,"UPDATE dbo.TDSCNews SET Title=@title,SummaryText=@summary,BodyText=@body,AudienceMode=@audience,StatusCode=@status,PublishedAt=CASE WHEN @status=N'PUBLISHED' THEN COALESCE(PublishedAt,SYSUTCDATETIME()) ELSE NULL END,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.NewsID WHERE CompanyID=@company AND NewsID=@id",token,("@id",id),("@company",company),("@title",request.Title.Trim()),("@summary",Clean(request.Summary)),("@body",request.Body.Trim()),("@audience",request.AudienceMode),("@status",status),("@user",user))
   :await Scalar<long>(db,null,"INSERT dbo.TDSCNews(CompanyID,Title,SummaryText,BodyText,AudienceMode,StatusCode,PublishedAt,CreateBy) OUTPUT INSERTED.NewsID VALUES(@company,@title,@summary,@body,@audience,@status,CASE WHEN @status=N'PUBLISHED' THEN SYSUTCDATETIME() END,@user)",token,("@company",company),("@title",request.Title.Trim()),("@summary",Clean(request.Summary)),("@body",request.Body.Trim()),("@audience",request.AudienceMode),("@status",status),("@user",user));
  return saved>0?Ok(new{id=saved}):NotFound();
 }
 [HttpDelete("news/{id:long}")]
 public async Task<IActionResult> DeleteNews(long id,CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"52010","DELETE",token))return Forbid();
  await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);try{
   await Execute(db,tx,"DELETE a FROM dbo.TDSCNewsAudience a JOIN dbo.TDSCNews n ON n.NewsID=a.NewsID WHERE n.CompanyID=@company AND a.NewsID=@id",token,("@company",company),("@id",id));
   var count=await Execute(db,tx,"DELETE dbo.TDSCNews WHERE CompanyID=@company AND NewsID=@id",token,("@company",company),("@id",id));
   await tx.CommitAsync(token);return count>0?NoContent():NotFound();
  }catch{await tx.RollbackAsync(token);throw;}
 }
 [HttpGet("options")]
 public async Task<IActionResult> Options(CancellationToken token)
 {
  if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await AnyView(db,token))return Forbid();
  var levels=await Query(db,"SELECT LevelID id,LevelCode code,LevelName name FROM dbo.TDSCSchoolLevel WHERE CompanyID=@company AND IsActive=1 ORDER BY SortOrder",token,("@company",company));
  var rounds=await Query(db,"SELECT RoundID id,RoundCode code,RoundName name FROM dbo.TDSCLearningRound WHERE CompanyID=@company AND IsActive=1 ORDER BY RoundName",token,("@company",company));
  var rooms=await Query(db,"SELECT ClassroomID id,RoomCode code,RoomName name FROM dbo.TDSCClassroom WHERE CompanyID=@company AND IsActive=1 ORDER BY RoomName",token,("@company",company));
  var subjects=await Query(db,"SELECT SubjectID id,SubjectCode code,SubjectName name FROM dbo.TDSCSubject WHERE CompanyID=@company AND IsActive=1 ORDER BY SubjectName",token,("@company",company));
  var tables=await Query(db,"SELECT t.TimetableID id,CONCAT(c.RoomName,N' · ',s.SubjectName,N' · คาบ ',t.PeriodNo) name FROM dbo.TDSCTimetable t JOIN dbo.TDSCClassroom c ON c.ClassroomID=t.ClassroomID JOIN dbo.TDSCSubject s ON s.SubjectID=t.SubjectID WHERE t.CompanyID=@company AND t.IsActive=1 ORDER BY c.RoomName,t.PeriodNo",token,("@company",company));
  var students=await Query(db,"SELECT StudentID id,StudentCode code,CONCAT(FirstName,N' ',LastName) name FROM dbo.TDSCStudent WHERE CompanyID=@company AND IsActive=1 ORDER BY StudentCode",token,("@company",company));
  return Ok(new{levels,rounds,rooms,subjects,timetables=tables,students});
 }
 [HttpGet("reports/{type}")]
 public async Task<IActionResult> Reports(string type,DateTime? from,DateTime? to,CancellationToken token)
 {
  var menu=type=="period"?"52012":"52011";if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,menu,"VIEW",token))return Forbid();
  var start=(from??DateTime.Today.AddDays(-30)).Date;var end=(to??DateTime.Today).Date;
  if(type=="period")return Ok(await Query(db,"SELECT s.StudentCode code,CONCAT(s.FirstName,N' ',s.LastName) name,COUNT(*) total,SUM(CASE WHEN d.StatusCode IN(N'PRESENT',N'LATE') THEN 1 ELSE 0 END) attended,SUM(CASE WHEN d.StatusCode=N'ABSENT' THEN 1 ELSE 0 END) absent FROM dbo.TDSCPeriodAttendance h JOIN dbo.TDSCPeriodAttendanceDetail d ON d.PeriodAttendanceID=h.PeriodAttendanceID JOIN dbo.TDSCStudent s ON s.StudentID=d.StudentID WHERE h.CompanyID=@company AND h.AttendanceDate BETWEEN @from AND @to GROUP BY s.StudentCode,s.FirstName,s.LastName ORDER BY s.StudentCode",token,("@company",company),("@from",start),("@to",end)));
  return Ok(await Query(db,"SELECT s.StudentCode code,CONCAT(s.FirstName,N' ',s.LastName) name,COUNT(a.AttendanceID) total,SUM(CASE WHEN a.StatusCode=N'LATE' THEN 1 ELSE 0 END) late,SUM(CASE WHEN a.StatusCode=N'ABSENT' THEN 1 ELSE 0 END) absent FROM dbo.TDSCStudent s LEFT JOIN dbo.TDSCSchoolAttendance a ON a.StudentID=s.StudentID AND a.AttendanceDate BETWEEN @from AND @to WHERE s.CompanyID=@company GROUP BY s.StudentCode,s.FirstName,s.LastName ORDER BY s.StudentCode",token,("@company",company),("@from",start),("@to",end)));
 }
 static string MasterSaveSql(string type,bool edit)=>(type,edit) switch{
  ("level",false)=>"INSERT dbo.TDSCSchoolLevel(CompanyID,LevelCode,LevelName,SortOrder,IsActive,CreateBy) OUTPUT INSERTED.LevelID VALUES(@company,@code,@name,@sort,@active,@user)",
  ("level",true)=>"UPDATE dbo.TDSCSchoolLevel SET LevelCode=@code,LevelName=@name,SortOrder=@sort,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.LevelID WHERE CompanyID=@company AND LevelID=@id",
  ("subject",false)=>"INSERT dbo.TDSCSubject(CompanyID,SubjectCode,SubjectName,IsActive,CreateBy) OUTPUT INSERTED.SubjectID VALUES(@company,@code,@name,@active,@user)",
  ("subject",true)=>"UPDATE dbo.TDSCSubject SET SubjectCode=@code,SubjectName=@name,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.SubjectID WHERE CompanyID=@company AND SubjectID=@id",
  ("holiday",false)=>"INSERT dbo.TDSCHoliday(CompanyID,HolidayDate,HolidayName,IsActive,CreateBy) OUTPUT INSERTED.HolidayID VALUES(@company,@date,@name,@active,@user)",
  ("holiday",true)=>"UPDATE dbo.TDSCHoliday SET HolidayDate=@date,HolidayName=@name,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.HolidayID WHERE CompanyID=@company AND HolidayID=@id",
  _=>MasterSaveSql2(type,edit)};
 static string MasterSaveSql2(string type,bool edit)=>(type,edit) switch{
  ("round",false)=>"INSERT dbo.TDSCLearningRound(CompanyID,LevelID,RoundCode,RoundName,CheckInTime,CheckOutTime,LateAfter,IsActive,CreateBy) OUTPUT INSERTED.RoundID VALUES(@company,@parent,@code,@name,@start,@end,@late,@active,@user)",
  ("round",true)=>"UPDATE dbo.TDSCLearningRound SET LevelID=@parent,RoundCode=@code,RoundName=@name,CheckInTime=@start,CheckOutTime=@end,LateAfter=@late,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.RoundID WHERE CompanyID=@company AND RoundID=@id",
  ("classroom",false)=>"INSERT dbo.TDSCClassroom(CompanyID,LevelID,RoomCode,RoomName,AcademicYear,IsActive,CreateBy) OUTPUT INSERTED.ClassroomID VALUES(@company,@parent,@code,@name,@year,@active,@user)",
  ("classroom",true)=>"UPDATE dbo.TDSCClassroom SET LevelID=@parent,RoomCode=@code,RoomName=@name,AcademicYear=@year,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.ClassroomID WHERE CompanyID=@company AND ClassroomID=@id",
  _=>throw new ArgumentOutOfRangeException(nameof(type))};
 static (string Type,string Menu)? MasterSpec(string value)=>value.Trim().ToLowerInvariant() switch{
  "level"=>("level","52002"),"round"=>("round","52003"),"holiday"=>("holiday","52004"),
  "subject"=>("subject","52005"),"classroom"=>("classroom","52005"),_=>null};
 static (string Table,string Id)? MasterDeleteSpec(string value)=>value.Trim().ToLowerInvariant() switch{
  "level"=>("TDSCSchoolLevel","LevelID"),"round"=>("TDSCLearningRound","RoundID"),
  "holiday"=>("TDSCHoliday","HolidayID"),"subject"=>("TDSCSubject","SubjectID"),
  "classroom"=>("TDSCClassroom","ClassroomID"),_=>null};
 async Task<bool> AnyView(SqlConnection db,CancellationToken token){foreach(var menu in Menus)if(await Can(db,menu,"VIEW",token))return true;return false;}
 bool Scope(out long company,out long user)
 {
  company=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"
   &&long.TryParse(User.FindFirstValue("company_id"),out company)
   &&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;
 }
 async Task<SqlConnection> Open(CancellationToken token)
 {
  var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
  await db.OpenAsync(token);return db;
 }
 async Task<bool> Can(SqlConnection db,string menu,string action,CancellationToken token)=>
  await CompanyMenuAccess.IsAllowedAsync(db,User,menu,action,token);
 static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
 IActionResult Bad(string message,string description)=>BadRequest(new{message,description});
 static void Params(SqlCommand cmd,IEnumerable<(string,object?)> values)
 {
  foreach(var(name,value)in values){if(!cmd.Parameters.Contains(name))cmd.Parameters.AddWithValue(name,value??DBNull.Value);}
 }
 static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] values)
 {
  await using var cmd=new SqlCommand(sql,db);Params(cmd,values);await using var reader=await cmd.ExecuteReaderAsync(token);
  var rows=new List<Dictionary<string,object?>>();while(await reader.ReadAsync(token)){var row=new Dictionary<string,object?>(StringComparer.OrdinalIgnoreCase);for(var i=0;i<reader.FieldCount;i++)row[reader.GetName(i)]=await reader.IsDBNullAsync(i,token)?null:reader.GetValue(i);rows.Add(row);}return rows;
 }
 static async Task<int> Execute(SqlConnection db,SqlTransaction tx,string sql,CancellationToken token,params(string,object?)[] values)
 {
  await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);return await cmd.ExecuteNonQueryAsync(token);
 }
 static async Task<int> Execute(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] values)
 {
  await using var cmd=new SqlCommand(sql,db);Params(cmd,values);return await cmd.ExecuteNonQueryAsync(token);
 }
 static async Task<T> Scalar<T>(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken token,params(string,object?)[] values)
 {
  await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);var value=await cmd.ExecuteScalarAsync(token);return value is null or DBNull?default!:(T)Convert.ChangeType(value,Nullable.GetUnderlyingType(typeof(T))??typeof(T));
 }
}

public sealed record SchoolSettings(string AttendanceMode,bool RequirePeriodAttendance,int LateGraceMinutes,bool Active=true);
public sealed record SchoolMaster(string Code,string Name,long? ParentId=null,DateTime? Date=null,TimeSpan? StartTime=null,TimeSpan? EndTime=null,TimeSpan? LateAfter=null,int? AcademicYear=null,int SortOrder=0,bool Active=true);
public sealed record StudentRequest(string Code,string FirstName,string LastName,long ClassroomId,long? RoundId=null,bool Active=true);
public sealed record GuardianRequest(string Code,string FullName,string Email,string? Telephone=null,bool Active=true,List<long>? StudentIds=null);
public sealed record TimetableRequest(long ClassroomId,long SubjectId,int DayOfWeek,int PeriodNo,TimeSpan StartTime,TimeSpan EndTime,string? LearningRoom=null,bool Active=true);
public sealed record SchoolAttendanceRequest(long StudentId,DateTime Date,DateTime? CheckInAt,DateTime? CheckOutAt,string Status,string? Remark);
public sealed record PeriodAttendanceRow(long StudentId,string Status,string? Remark);
public sealed record PeriodAttendanceRequest(long TimetableId,DateTime Date,List<PeriodAttendanceRow> Students);
public sealed record NewsRequest(string Title,string? Summary,string Body,string AudienceMode,bool Publish=false);
