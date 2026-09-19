using System.Data;
using System.Security.Claims;
using System.Text.Json;
using LaooTrainingModule.Assessments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTrainingModule.Controllers;

[ApiController, Authorize]
[Route("api/company/training/bookings/{bookingId:long}/tests")]
public sealed class TrainingExamController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private long company, user, partner;
    private SqlConnection db = null!;
    private SqlTransaction tx = null!;
    private Access access = null!;
    private static readonly JsonSerializerOptions Json = ExamRules.Json;

    [HttpGet]
    public Task<IActionResult> Overview(long bookingId, CancellationToken token) => Run(bookingId, async () =>
    {
        var exams = await Rows("SELECT SectionCode,DefinitionJson,RowVersion FROM dbo.TDTRBookingExam WHERE CompanyID=@company AND BookingID=@booking", token);
        return Ok(new {
            access.Subject, access.CanManage, access.ParticipantId, access.FirstStart, access.LastEnd,
            sections = new[] {"PRE","POST"}.Select(section => {
                var row = exams.SingleOrDefault(x => (string)x["SectionCode"]! == section);
                var definition = row is null ? null : Read<ExamDefinition>(row["DefinitionJson"]);
                return new { section, configured = definition is not null,
                    isActive = definition?.IsActive ?? false,
                    isOpen = Open(section) && definition?.IsActive == true,
                    questionCount = definition?.QuestionCount ?? 0,
                    passingPercent = definition?.PassingPercent ?? 60 };
            })
        });
    }, token);

    [HttpGet("{section}/definition")]
    public Task<IActionResult> Definition(long bookingId, string section, CancellationToken token) => Run(bookingId, async () =>
    {
        Manage(); Section(section);
        var row = await Exam(section, token);
        return Ok(new { definition = row is null ? null : Read<ExamDefinition>(row["DefinitionJson"]),
            rowVersion = row is null ? null : Version(row),
            locked = row is not null && await HasAttempts((long)row["ExamID"]!, token) });
    }, token);

    [HttpPut("{section}/definition")]
    public Task<IActionResult> SaveDefinition(long bookingId, string section, SaveExam request, CancellationToken token) => Run(bookingId, async () =>
    {
        Manage(); Section(section);
        var error = ExamRules.Validate(request.Definition);
        if (error is not null) throw new ExamFailure(400, error);
        var row = await Exam(section, token);
        if (row is not null) {
            if (await HasAttempts((long)row["ExamID"]!, token))
                throw new ExamFailure(409, "มีผู้เริ่มทำข้อสอบแล้ว ไม่สามารถเปลี่ยนชุดข้อสอบหรือเกณฑ์คะแนน");
            RequireVersion(row, request.RowVersion);
        }
        foreach (var id in ExamRules.Images(request.Definition.Questions))
            if (await Scalar("SELECT COUNT(*) FROM dbo.TDTRBookingExamImage WHERE CompanyID=@company AND BookingID=@booking AND ImageID=@id", token, ("@id",id)) is not int count || count != 1)
                throw new ExamFailure(400, "รูปภาพไม่อยู่ในการอบรมนี้ กรุณาอัปโหลดใหม่");
        await Execute(row is null
            ? "INSERT dbo.TDTRBookingExam(CompanyID,BookingID,SectionCode,DefinitionJson,CreateBy,UpdateBy) VALUES(@company,@booking,@section,@json,@user,@user)"
            : "UPDATE dbo.TDTRBookingExam SET DefinitionJson=@json,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND BookingID=@booking AND SectionCode=@section",
            token, ("@section",section), ("@json",Write(request.Definition)));
        return Ok(new { saved = true });
    }, token);

    [HttpPost("{section}/attempt")]
    public Task<IActionResult> Start(long bookingId, string section, CancellationToken token) => Run(bookingId, async () =>
    {
        Section(section); Participant();
        var exam = await RequiredExam(section, token);
        var attempt = await Attempt((long)exam["ExamID"]!, token);
        if (attempt is not null) return Ok(ParticipantView(attempt, section));
        RequireOpen(section);
        var definition = Read<ExamDefinition>(exam["DefinitionJson"]);
        if (!definition.IsActive) throw new ExamFailure(409, "แบบทดสอบนี้ยังไม่เปิดใช้งาน");
        var snapshot = ExamRules.Sample(definition);
        await Execute("""
INSERT dbo.TDTRBookingExamAttempt(ExamID,CompanyID,BookingParticipantID,EmployeeCodeSnapshot,EmployeeNameSnapshot,SnapshotJson,MaxScore,PassingPercent,UpdateBy)
VALUES(@exam,@company,@participant,@code,@name,@snapshot,@max,@passing,@user)
""", token, ("@exam",exam["ExamID"]), ("@participant",access.ParticipantId),
            ("@code",access.EmployeeCode), ("@name",access.EmployeeName),
            ("@snapshot",Write(snapshot)), ("@max",snapshot.Questions.Count), ("@passing",snapshot.PassingPercent));
        return Ok(ParticipantView((await Attempt((long)exam["ExamID"]!, token))!, section));
    }, token);

    [HttpPut("{section}/attempt")]
    public Task<IActionResult> Answer(long bookingId, string section, SaveAnswers request, CancellationToken token) => Run(bookingId, async () =>
    {
        Section(section); Participant();
        var exam = await RequiredExam(section, token);
        var attempt = await Attempt((long)exam["ExamID"]!, token)
            ?? throw new ExamFailure(409, "กรุณาเริ่มแบบทดสอบก่อนบันทึกคำตอบ");
        if (attempt["SubmittedDate"] is not null) {
            if (request.Submit) return Ok(ParticipantView(attempt, section));
            throw new ExamFailure(409, "ส่งข้อสอบแล้ว ไม่สามารถแก้ไขคำตอบ");
        }
        RequireOpen(section);
        RequireVersion(attempt, request.RowVersion);
        var snapshot = Read<ExamSnapshot>(attempt["SnapshotJson"]);
        var error = ExamRules.ValidateAnswers(snapshot, request.Answers, request.Submit);
        if (error is not null) throw new ExamFailure(400, error);
        var score = request.Submit ? ExamRules.Score(snapshot, request.Answers) : null;
        await Execute("""
UPDATE dbo.TDTRBookingExamAttempt SET AnswersJson=@answers,UpdateBy=@user,
SubmittedDate=CASE WHEN @submit=1 THEN SYSUTCDATETIME() ELSE NULL END,Score=@score,Passed=@passed
WHERE AttemptID=@id AND CompanyID=@company
""", token, ("@answers",Write(request.Answers)), ("@submit",request.Submit),
            ("@score",score?.Score), ("@passed",score?.Passed), ("@id",attempt["AttemptID"]));
        return Ok(ParticipantView((await Attempt((long)exam["ExamID"]!, token))!, section));
    }, token);

    [HttpGet("{section}/results")]
    public Task<IActionResult> Results(long bookingId, string section, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30, CancellationToken token = default) => Run(bookingId, async () =>
    {
        Section(section);
        if (!access.CanManage) Participant();
        page = Math.Max(1,page); pageSize = Math.Clamp(pageSize,1,100);
        var rows = await Rows("""
SELECT A.AttemptID,A.BookingParticipantID,A.EmployeeCodeSnapshot,A.EmployeeNameSnapshot,
A.Score,A.MaxScore,A.Passed,A.SubmittedDate,A.StartedDate
FROM dbo.TDTRBookingExamAttempt A JOIN dbo.TDTRBookingExam E ON E.ExamID=A.ExamID AND E.CompanyID=A.CompanyID
WHERE E.CompanyID=@company AND E.BookingID=@booking AND E.SectionCode=@section
AND (@manage=1 OR A.BookingParticipantID=@participant)
ORDER BY CASE WHEN A.SubmittedDate IS NULL THEN 1 ELSE 0 END,A.Score DESC,A.SubmittedDate,A.EmployeeNameSnapshot,A.AttemptID
""", token, ("@section",section), ("@manage",access.CanManage), ("@participant",access.ParticipantId));
        return Ok(new {
            total=rows.Count, page, pageSize,
            passed=rows.Count(r => r["Passed"] is true),
            failed=rows.Count(r => r["Passed"] is false),
            unfinished=rows.Count(r => r["SubmittedDate"] is null),
            items=rows.Skip((page-1)*pageSize).Take(pageSize).Select((r,i) => new {
                order=(page-1)*pageSize+i+1,
                participantId=r["BookingParticipantID"], code=r["EmployeeCodeSnapshot"], name=r["EmployeeNameSnapshot"],
                score=r["Score"], maxScore=r["MaxScore"],
                percent=r["Score"] is int s ? decimal.Round(s*100m/(int)r["MaxScore"]!,2) : (decimal?)null,
                result=r["SubmittedDate"] is null ? "UNFINISHED" : r["Passed"] is true ? "PASSED" : "FAILED",
                submittedDate=r["SubmittedDate"] is DateTime date ? DateTime.SpecifyKind(date,DateTimeKind.Utc) : (DateTime?)null
            })
        });
    }, token);

    [HttpPost("images"), RequestSizeLimit(1500000)]
    public Task<IActionResult> Upload(long bookingId, UploadImage request, CancellationToken token) => Run(bookingId, async () =>
    {
        Manage();
        byte[] bytes;
        try { bytes=Convert.FromBase64String(request.Base64 ?? ""); }
        catch (FormatException) { throw new ExamFailure(400,"ไฟล์รูปไม่ถูกต้อง กรุณาเลือกรูปใหม่"); }
        var type=ExamRules.ImageType(bytes) ?? throw new ExamFailure(400,"รับเฉพาะ JPG, PNG, WebP ขนาดไม่เกิน 1 MB");
        var id=Guid.NewGuid();
        var file=ImageFile(bookingId,id);
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        await System.IO.File.WriteAllBytesAsync(file,bytes,token);
        try {
            await Execute("INSERT dbo.TDTRBookingExamImage(ImageID,CompanyID,BookingID,ContentType,ByteLength,CreateBy) VALUES(@id,@company,@booking,@type,@size,@user)",
                token,("@id",id),("@type",type),("@size",bytes.Length));
        } catch { System.IO.File.Delete(file); throw; }
        return Ok(new { id, contentType=type });
    }, token);

    [HttpGet("images/{imageId:guid}")]
    public Task<IActionResult> Image(long bookingId, Guid imageId, CancellationToken token) => Run(bookingId, async () =>
    {
        if (!access.CanManage) {
            Participant();
            var attempts=await Rows("""
SELECT A.SnapshotJson FROM dbo.TDTRBookingExamAttempt A JOIN dbo.TDTRBookingExam E ON E.ExamID=A.ExamID AND E.CompanyID=A.CompanyID
WHERE E.CompanyID=@company AND E.BookingID=@booking AND A.BookingParticipantID=@participant
""",token,("@participant",access.ParticipantId));
            if (!attempts.Any(a=>ExamRules.Images(Read<ExamSnapshot>(a["SnapshotJson"]).Questions).Contains(imageId)))
                throw new ExamFailure(403,"ไม่มีสิทธิ์อ่านรูปข้อสอบนี้");
        }
        var type=await Scalar("SELECT ContentType FROM dbo.TDTRBookingExamImage WHERE CompanyID=@company AND BookingID=@booking AND ImageID=@id",token,("@id",imageId));
        if (type is not string contentType || !System.IO.File.Exists(ImageFile(bookingId,imageId)))
            throw new ExamFailure(404,"ไม่พบรูปภาพ");
        Response.Headers.CacheControl="no-store";
        return Ok(new { contentType, base64=Convert.ToBase64String(await System.IO.File.ReadAllBytesAsync(ImageFile(bookingId,imageId),token)) });
    }, token);

    [HttpDelete("images/{imageId:guid}")]
    public Task<IActionResult> DeleteImage(long bookingId, Guid imageId, CancellationToken token) => Run(bookingId, async () =>
    {
        Manage();
        var definitions=await Rows("SELECT DefinitionJson FROM dbo.TDTRBookingExam WHERE CompanyID=@company AND BookingID=@booking",token);
        var snapshots=await Rows("""
SELECT A.SnapshotJson FROM dbo.TDTRBookingExamAttempt A JOIN dbo.TDTRBookingExam E ON E.ExamID=A.ExamID AND E.CompanyID=A.CompanyID
WHERE E.CompanyID=@company AND E.BookingID=@booking
""",token);
        if (definitions.Any(r=>ExamRules.Images(Read<ExamDefinition>(r["DefinitionJson"]).Questions).Contains(imageId)) ||
            snapshots.Any(r=>ExamRules.Images(Read<ExamSnapshot>(r["SnapshotJson"]).Questions).Contains(imageId)))
            throw new ExamFailure(409,"รูปนี้ถูกใช้อยู่ในข้อสอบหรือประวัติการสอบ จึงลบไม่ได้");
        await Execute("DELETE dbo.TDTRBookingExamImage WHERE CompanyID=@company AND BookingID=@booking AND ImageID=@id",token,("@id",imageId));
        // Remove the private file only after its metadata transaction commits.
        pendingDelete=ImageFile(bookingId,imageId);
        return NoContent();
    }, token);

    private string? pendingDelete;
    private async Task<IActionResult> Run(long bookingId, Func<Task<IActionResult>> action, CancellationToken token)
    {
        if (User.FindFirstValue("user_type")!="COMPANY_USER" ||
            !long.TryParse(User.FindFirstValue("company_id"),out company) ||
            !long.TryParse(User.FindFirstValue("partner_id"),out partner) ||
            !long.TryParse(User.FindFirstValue("user_id"),out user))
            return StatusCode(403,Error("ไม่มีสิทธิ์ใช้งาน","กรุณาเข้าสู่ระบบด้วยบัญชีบริษัท"));
        await using var connection=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token); db=connection;
        await using var transaction=(SqlTransaction)await db.BeginTransactionAsync(token); tx=transaction;
        currentBooking=bookingId;
        try {
            await Execute("""
DECLARE @result int;
EXEC @result=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
IF @result<0 THROW 52930,'EXAM_BUSY',1;
""",token,("@resource",$"TrainingExam:{company}:{bookingId}"));
            access=await LoadAccess(token) ?? throw new ExamFailure(403,"ไม่พบการอบรมในขอบเขตบริษัท หรือไม่มีสิทธิ์ Training");
            if (!access.CanManage && access.ParticipantId is null)
                throw new ExamFailure(403,"ต้องเป็นผู้ดูแลหรือผู้เข้าร่วมที่ตอบรับแล้ว");
            Response.Headers.CacheControl="no-store";
            var result=await action();
            await tx.CommitAsync(token);
            if (pendingDelete is not null) System.IO.File.Delete(pendingDelete);
            return result;
        } catch (ExamFailure e) {
            await tx.RollbackAsync(CancellationToken.None);
            return StatusCode(e.Status,Error("ดำเนินการแบบทดสอบไม่สำเร็จ",e.Message));
        } catch (SqlException e) when (e.Number is 52930 or 1205) {
            await tx.RollbackAsync(CancellationToken.None);
            return Conflict(Error("มีการดำเนินการพร้อมกัน","กรุณาโหลดแบบทดสอบใหม่แล้วลองอีกครั้ง"));
        }
    }

    private long currentBooking;
    private async Task<Access?> LoadAccess(CancellationToken token)
    {
        var rows=await Rows("""
SELECT B.Subject,B.BookingStatus,U.IsCompanyAdmin,B.RequesterUserID,
(SELECT MIN(StartDateTime) FROM dbo.TDADMeetingRoomBookingSlot WHERE BookingID=B.BookingID AND CompanyID=B.CompanyID) FirstStart,
(SELECT MAX(EndDateTime) FROM dbo.TDADMeetingRoomBookingSlot WHERE BookingID=B.BookingID AND CompanyID=B.CompanyID) LastEnd,
CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADMeetingRoomContact RC
 JOIN dbo.TDADMeetingRoom R ON R.RoomID=RC.RoomID AND R.CompanyID=B.CompanyID
 JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=R.CompanyID AND UE.EmployeeID=RC.EmployeeID AND UE.UserID=@user AND UE.IsActive=1
 JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
 WHERE RC.RoomID=B.RoomID AND RC.IsActive=1) THEN 1 ELSE 0 END RoomAdmin,
P.BookingParticipantID,P.EmployeeCode,P.FullName
FROM dbo.TDADMeetingRoomBooking B
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=B.CompanyID AND C.PartnerID=@partner AND C.IsActive=1
JOIN dbo.TDADUser U ON U.CompanyID=B.CompanyID AND U.UserID=@user AND U.IsActive=1
OUTER APPLY (
 SELECT TOP(1) BP.BookingParticipantID,E.EmployeeCode,E.FullName
 FROM dbo.TDADMeetingRoomBookingParticipant BP
 JOIN dbo.TDADEmployee E ON E.EmployeeID=BP.EmployeeID AND E.CompanyID=BP.CompanyID AND E.IsActive=1
 WHERE BP.BookingID=B.BookingID AND BP.CompanyID=B.CompanyID AND BP.InvitationStatus='ACCEPTED'
 AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.EmployeeID=BP.EmployeeID AND UE.CompanyID=BP.CompanyID AND UE.UserID=@user AND UE.IsActive=1)
 ORDER BY BP.BookingParticipantID
) P
WHERE B.CompanyID=@company AND B.BookingID=@booking AND B.ActivityTypeCode='TRAINING'
AND EXISTS (
 SELECT 1 FROM dbo.TDADProject PR
 JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=PR.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1
 JOIN dbo.TDADUserProject UP ON UP.ProjectID=PR.ProjectID AND UP.CompanyID=C.CompanyID AND UP.UserID=@user AND UP.IsActive=1
 WHERE PR.ProjectCode='LAOO_TRAINING' AND PR.IsActive=1
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
)
""",token);
        var r=rows.SingleOrDefault();
        return r is null || r["FirstStart"] is not DateTime start || r["LastEnd"] is not DateTime end ? null :
            new((string)r["Subject"]!, (string)r["BookingStatus"]!,
            r["IsCompanyAdmin"] is true || (long)r["RequesterUserID"]! == user || (int)r["RoomAdmin"]! == 1,
            r["BookingParticipantID"] as long?, r["EmployeeCode"] as string ?? "", r["FullName"] as string ?? "",start,end);
    }

    private bool Open(string section) => access.Status=="APPROVED" && ExamRules.IsOpen(section,DateTime.Now,access.FirstStart,access.LastEnd);
    private void RequireOpen(string section) { if (!Open(section)) throw new ExamFailure(409,"การอบรมยังไม่อนุมัติ หรืออยู่นอกช่วงเวลาทำแบบทดสอบ"); }
    private void Manage() { if (!access.CanManage) throw new ExamFailure(403,"เฉพาะเจ้าของการจอง Admin ห้อง หรือ Company Admin"); }
    private void Participant() { if (access.ParticipantId is null) throw new ExamFailure(403,"ต้องเป็นผู้เข้าร่วมที่ตอบรับแล้ว"); }
    private static void Section(string section) { if (section is not ("PRE" or "POST")) throw new ExamFailure(400,"ประเภทข้อสอบต้องเป็น PRE หรือ POST"); }
    private static object Error(string message,string description) => new { message,description };
    private static T Read<T>(object? value) => JsonSerializer.Deserialize<T>((string)value!,Json)!;
    private static string Write<T>(T value) => JsonSerializer.Serialize(value,Json);
    private static string Version(Dictionary<string,object?> row) => Convert.ToBase64String((byte[])row["RowVersion"]!);
    private static void RequireVersion(Dictionary<string,object?> row,string? version) {
        if (version!=Version(row)) throw new ExamFailure(409,"ข้อมูลเปลี่ยนแล้ว กรุณาโหลดใหม่ก่อนบันทึก");
    }
    private Task<List<Dictionary<string,object?>>> ExamRows(string section,CancellationToken token) =>
        Rows("SELECT * FROM dbo.TDTRBookingExam WHERE CompanyID=@company AND BookingID=@booking AND SectionCode=@section",token,("@section",section));
    private async Task<Dictionary<string,object?>?> Exam(string section,CancellationToken token) => (await ExamRows(section,token)).SingleOrDefault();
    private async Task<Dictionary<string,object?>> RequiredExam(string section,CancellationToken token) =>
        await Exam(section,token) ?? throw new ExamFailure(404,"ยังไม่ได้กำหนดแบบทดสอบ");
    private async Task<bool> HasAttempts(long exam,CancellationToken token) =>
        (int)(await Scalar("SELECT COUNT(*) FROM dbo.TDTRBookingExamAttempt WHERE ExamID=@exam AND CompanyID=@company",token,("@exam",exam)))!>0;
    private async Task<Dictionary<string,object?>?> Attempt(long exam,CancellationToken token) =>
        (await Rows("SELECT * FROM dbo.TDTRBookingExamAttempt WHERE ExamID=@exam AND CompanyID=@company AND BookingParticipantID=@participant",token,("@exam",exam),("@participant",access.ParticipantId))).SingleOrDefault();
    private object ParticipantView(Dictionary<string,object?> row,string section) {
        var snapshot=Read<ExamSnapshot>(row["SnapshotJson"]);
        return new { attemptId=row["AttemptID"], rowVersion=Version(row), section,
            submitted=row["SubmittedDate"] is not null, canAnswer=row["SubmittedDate"] is null && Open(section),
            score=row["Score"], maxScore=row["MaxScore"], passed=row["Passed"], passingPercent=row["PassingPercent"],
            answers=Read<List<ExamAnswer>>(row["AnswersJson"]),
            questions=snapshot.Questions.Select(q=>new { q.Id,q.Text,q.ImageId,
                options=q.Options.Select((o,i)=>new { o.Id,o.Text,o.ImageId,number=i+1 }) }) };
    }
    private string ImageFile(long booking,Guid id) => Path.Combine(environment.ContentRootPath,"App_Data","training-tests",company.ToString(),booking.ToString(),id.ToString("N"));
    private SqlCommand Command(string sql,params (string Name,object? Value)[] args) {
        var command=new SqlCommand(sql,db,tx);
        command.Parameters.AddWithValue("@company",company); command.Parameters.AddWithValue("@booking",currentBooking);
        command.Parameters.AddWithValue("@user",user); command.Parameters.AddWithValue("@partner",partner);
        foreach (var (name,value) in args) command.Parameters.AddWithValue(name,value??DBNull.Value);
        return command;
    }
    private async Task Execute(string sql,CancellationToken token,params (string,object?)[] args) {
        await using var command=Command(sql,args); await command.ExecuteNonQueryAsync(token);
    }
    private async Task<object?> Scalar(string sql,CancellationToken token,params (string,object?)[] args) {
        await using var command=Command(sql,args); return await command.ExecuteScalarAsync(token);
    }
    private async Task<List<Dictionary<string,object?>>> Rows(string sql,CancellationToken token,params (string,object?)[] args) {
        await using var command=Command(sql,args); await using var reader=await command.ExecuteReaderAsync(token);
        var rows=new List<Dictionary<string,object?>>();
        while(await reader.ReadAsync(token)) {
            var row=new Dictionary<string,object?>();
            for(var i=0;i<reader.FieldCount;i++) row[reader.GetName(i)]=reader.IsDBNull(i)?null:reader.GetValue(i);
            rows.Add(row);
        }
        return rows;
    }
    private sealed record Access(string Subject,string Status,bool CanManage,long? ParticipantId,string EmployeeCode,string EmployeeName,DateTime FirstStart,DateTime LastEnd);
    private sealed class ExamFailure(int status,string message):Exception(message) { public int Status {get;}=status; }
}
public sealed record SaveExam(ExamDefinition Definition,string? RowVersion);
public sealed record SaveAnswers(List<ExamAnswer> Answers,bool Submit,string? RowVersion);
public sealed record UploadImage(string Base64);
