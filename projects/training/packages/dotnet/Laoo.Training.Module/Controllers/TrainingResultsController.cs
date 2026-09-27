using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTrainingModule.Controllers;

[ApiController, Authorize]
[Route("api/company/training/results")]
public sealed class TrainingResultsController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] int page=1,[FromQuery] int pageSize=30,[FromQuery] string? search=null,[FromQuery] string? course=null,[FromQuery] string? status=null,CancellationToken token=default)
    {
        if(!Scope(out var company,out var partner,out var user)) return Forbid();
        page=Math.Max(1,page); pageSize=Math.Clamp(pageSize,1,100); await using var db=await Open(token);
        const string where="""
WHERE B.CompanyID=@company AND B.ActivityTypeCode=N'TRAINING'
AND EXISTS(SELECT 1 FROM dbo.TDADProject PR JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=PR.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1 WHERE PR.ProjectCode=N'LAOO_TRAINING' AND PR.IsActive=1 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
AND (U.IsCompanyAdmin=1 OR B.RequesterUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomContact RC JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=B.CompanyID AND UE.EmployeeID=RC.EmployeeID AND UE.UserID=@user AND UE.IsActive=1 WHERE RC.RoomID=B.RoomID AND RC.IsActive=1))
AND (@search IS NULL OR @search=N'' OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%')
AND (@course IS NULL OR @course=N'' OR B.Subject LIKE N'%'+@course+N'%')
AND (@status IS NULL OR @status=N'' OR B.BookingStatus=@status)
""";
        const string joins="""
FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADUser U ON U.UserID=@user AND U.CompanyID=B.CompanyID AND U.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=B.CompanyID AND C.PartnerID=@partner AND C.IsActive=1
""";
        var total=Convert.ToInt64(await Scalar($"SELECT COUNT_BIG(*) {joins} {where}",db,company,partner,user,search,token,("@course",course),("@status",status)));
        var rows=await Rows($"""
SELECT B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,MIN(S.StartDateTime) StartDateTime,MAX(S.EndDateTime) EndDateTime,
COUNT(P.BookingParticipantID) Invited,SUM(CASE WHEN P.InvitationStatus=N'ACCEPTED' AND ISNULL(P.IsLateResponse,0)=0 THEN 1 ELSE 0 END) Accepted,SUM(CASE WHEN P.InvitationStatus=N'ACCEPTED' AND ISNULL(P.IsLateResponse,0)=1 THEN 1 ELSE 0 END) LateAccepted,SUM(CASE WHEN P.InvitationStatus=N'PENDING' THEN 1 ELSE 0 END) Pending,SUM(CASE WHEN P.InvitationStatus=N'DECLINED' THEN 1 ELSE 0 END) Declined
{joins} JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID LEFT JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.BookingID=B.BookingID AND P.CompanyID=B.CompanyID {where} GROUP BY B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH ORDER BY MIN(S.StartDateTime) DESC,B.BookingID DESC OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY
""",db,company,partner,user,search,token,("@course",course),("@status",status),("@offset",(page-1)*pageSize),("@pageSize",pageSize));
        return Ok(new {total,page,pageSize,items=rows.Select(Booking)});
    }

    [HttpGet("{bookingId:long}")]
    public async Task<IActionResult> Detail(long bookingId,CancellationToken token)
    {
        if(!Scope(out var company,out var partner,out var user)) return Forbid(); await using var db=await Open(token);
        if(!await Allowed(db,company,partner,user,bookingId,token)) return Forbid();
        var rows=await Rows("""
SELECT B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,MIN(S.StartDateTime) StartDateTime,MAX(S.EndDateTime) EndDateTime,COUNT(P.BookingParticipantID) Invited,SUM(CASE WHEN P.InvitationStatus=N'ACCEPTED' AND ISNULL(P.IsLateResponse,0)=0 THEN 1 ELSE 0 END) Accepted,SUM(CASE WHEN P.InvitationStatus=N'ACCEPTED' AND ISNULL(P.IsLateResponse,0)=1 THEN 1 ELSE 0 END) LateAccepted,SUM(CASE WHEN P.InvitationStatus=N'PENDING' THEN 1 ELSE 0 END) Pending,SUM(CASE WHEN P.InvitationStatus=N'DECLINED' THEN 1 ELSE 0 END) Declined
FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID LEFT JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.BookingID=B.BookingID AND P.CompanyID=B.CompanyID WHERE B.CompanyID=@company AND B.BookingID=@booking GROUP BY B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH
""",db,company,partner,user,null,token,("@booking",bookingId));
        return rows.Count==0?NotFound():Ok(Booking(rows[0]));
    }

    [HttpGet("{bookingId:long}/{section}")]
    public async Task<IActionResult> Section(long bookingId,string section,CancellationToken token)
    {
        if(section is not ("PRE" or "POST")) return BadRequest(new {message="ช่วงแบบทดสอบไม่ถูกต้อง",description="เลือก PRE หรือ POST"});
        if(!Scope(out var company,out var partner,out var user)) return Forbid(); await using var db=await Open(token);
        if(!await Allowed(db,company,partner,user,bookingId,token)) return Forbid();
        var rows=await Rows("""
SELECT P.BookingParticipantID,E.EmployeeCode,E.FullName,P.InvitationStatus,ISNULL(P.IsLateResponse,0) IsLateResponse,X.ExamID,X.SequenceNo,X.TrainingTestTemplateNameSnapshot,A.Score,A.MaxScore,A.Passed,A.SubmittedDate,A.StartedDate,
CASE WHEN X.ExamID IS NULL THEN N'NOT_CONFIGURED' WHEN P.InvitationStatus<>N'ACCEPTED' THEN N'NOT_ELIGIBLE' WHEN A.AttemptID IS NULL THEN N'NOT_STARTED' WHEN A.SubmittedDate IS NULL THEN N'IN_PROGRESS' ELSE N'SUBMITTED' END TestStatus
FROM dbo.TDADMeetingRoomBookingParticipant P JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=P.CompanyID
LEFT JOIN dbo.TDTRBookingExam X ON X.CompanyID=P.CompanyID AND X.BookingID=P.BookingID AND X.SectionCode=@section
LEFT JOIN dbo.TDTRBookingExamAttempt A ON A.CompanyID=P.CompanyID AND A.ExamID=X.ExamID AND A.BookingParticipantID=P.BookingParticipantID
WHERE P.CompanyID=@company AND P.BookingID=@booking
ORDER BY X.SequenceNo,CASE WHEN A.Score IS NULL THEN 1 ELSE 0 END,A.Score DESC,A.SubmittedDate,E.FullName,P.BookingParticipantID
""",db,company,partner,user,null,token,("@booking",bookingId),("@section",section));
        var items = rows.GroupBy(r => Convert.ToInt64(r["BookingParticipantID"])).Select(group =>
        {
            var participant = group.First();
            var eligible = string.Equals(participant["InvitationStatus"]?.ToString(), "ACCEPTED", StringComparison.OrdinalIgnoreCase);
            var exams = group.Where(r => r["ExamID"] is not null)
                .OrderBy(r => Convert.ToInt32(r["SequenceNo"] ?? 0)).ToList();
            var total = exams.Count;
            var submittedCount = exams.Count(r => r["SubmittedDate"] is not null);
            var passedCount = exams.Count(r => r["Passed"] is true);
            var completed = total > 0 && submittedCount == total;
            var failed = exams.Any(r => r["SubmittedDate"] is not null && r["Passed"] is false);
            var passedAll = completed && passedCount == total;
            var testStatus = !eligible ? "NOT_ELIGIBLE" : total == 0 ? "NOT_CONFIGURED" : completed ? "SUBMITTED" : submittedCount > 0 ? "IN_PROGRESS" : "NOT_STARTED";
            var result = !eligible || total == 0 ? null : failed ? "FAILED" : passedAll ? "PASSED" : "INCOMPLETE";
            return new
            {
                participantId = participant["BookingParticipantID"], code = participant["EmployeeCode"], name = participant["FullName"],
                invitationStatus = participant["InvitationStatus"], isLateResponse = participant["IsLateResponse"] is true,
                testStatus, result, total, submittedCount, passedCount, passedAll,
                exams = exams.Select(r => new
                {
                    examId = r["ExamID"], sequenceNo = r["SequenceNo"], templateName = r["TrainingTestTemplateNameSnapshot"],
                    score = r["Score"], maxScore = r["MaxScore"],
                    percent = r["Score"] is int score && r["MaxScore"] is int max ? decimal.Round(score * 100m / max, 2) : (decimal?)null,
                    status = r["TestStatus"], result = r["SubmittedDate"] is null ? null : r["Passed"] is true ? "PASSED" : "FAILED",
                    submittedDate = r["SubmittedDate"]
                })
            };
        }).ToList();
        return Ok(new
        {
            section,
            eligible = items.Count(r => r.invitationStatus?.ToString() == "ACCEPTED"),
            notStarted = items.Count(r => r.testStatus == "NOT_STARTED"),
            inProgress = items.Count(r => r.testStatus == "IN_PROGRESS"),
            submitted = items.Count(r => r.testStatus == "SUBMITTED"),
            passed = items.Count(r => r.result == "PASSED"),
            failed = items.Count(r => r.result == "FAILED"),
            items
        });
    }

    [HttpGet("{bookingId:long}/evaluations")]
    public async Task<IActionResult> Evaluations(long bookingId,CancellationToken token)
    {
        if(!Scope(out var company,out var partner,out var user))return Forbid();await using var db=await Open(token);
        if(!await Allowed(db,company,partner,user,bookingId,token))return Forbid();
        var rows=await Rows("""SELECT R.EvaluationRoundID,R.RoundNo,R.RoundName,R.SourceType,R.StatusCode,COUNT(RS.EvaluationRoundRespondentID) Eligible,SUM(CASE WHEN RS.AssignmentStatus='SUBMITTED' THEN 1 ELSE 0 END) Submitted FROM dbo.TDEVRound R LEFT JOIN dbo.TDEVRoundRespondent RS ON RS.CompanyID=R.CompanyID AND RS.EvaluationRoundID=R.EvaluationRoundID WHERE R.CompanyID=@company AND R.SourceProjectCode='LAOO_TRAINING' AND R.ReferenceEntityID=@booking AND R.SourceType IN('TRAINING_COURSE','TRAINING_INSTRUCTOR') GROUP BY R.EvaluationRoundID,R.RoundNo,R.RoundName,R.SourceType,R.StatusCode ORDER BY R.SourceType,R.CreateDate DESC""",db,company,partner,user,null,token,("@booking",bookingId));
        return Ok(new{items=rows.Select(r=>new{id=r["EvaluationRoundID"],roundNo=r["RoundNo"],name=r["RoundName"],sourceType=r["SourceType"],status=r["StatusCode"],eligible=Convert.ToInt32(r["Eligible"]),submitted=Convert.ToInt32(r["Submitted"])})});
    }

    private static object Booking(Dictionary<string,object?> r)=>new {bookingId=r["BookingID"],bookingNo=r["BookingNo"],subject=r["Subject"],status=r["BookingStatus"],roomCode=r["RoomCode"],roomName=r["RoomNameTH"],startDateTime=r["StartDateTime"],endDateTime=r["EndDateTime"],invited=Convert.ToInt32(r["Invited"]),accepted=Convert.ToInt32(r["Accepted"]),lateAccepted=Convert.ToInt32(r["LateAccepted"]),pending=Convert.ToInt32(r["Pending"]),declined=Convert.ToInt32(r["Declined"])};
    private bool Scope(out long company,out long partner,out long user){company=partner=user=0;return long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("partner_id"),out partner)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&User.FindFirstValue("user_type")=="COMPANY_USER";}
    private async Task<bool> Allowed(SqlConnection db,long company,long partner,long user,long booking,CancellationToken token)=>Convert.ToInt32(await Scalar("""SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADUser U ON U.UserID=@user AND U.CompanyID=B.CompanyID AND U.IsActive=1 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=B.CompanyID AND C.PartnerID=@partner AND C.IsActive=1 WHERE B.CompanyID=@company AND B.BookingID=@booking AND B.ActivityTypeCode=N'TRAINING' AND EXISTS(SELECT 1 FROM dbo.TDADProject PR JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=PR.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1 WHERE PR.ProjectCode=N'LAOO_TRAINING' AND PR.IsActive=1) AND (U.IsCompanyAdmin=1 OR B.RequesterUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomContact RC JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=B.CompanyID AND UE.EmployeeID=RC.EmployeeID AND UE.UserID=@user AND UE.IsActive=1 WHERE RC.RoomID=B.RoomID AND RC.IsActive=1))) THEN 1 ELSE 0 END""",db,company,partner,user,null,token,("@booking",booking)))==1;
    private async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    private static async Task<object?> Scalar(string sql,SqlConnection db,long company,long partner,long user,string? search,CancellationToken token,params (string,object?)[] args){await using var c=Command(sql,db,company,partner,user,search,args);return await c.ExecuteScalarAsync(token);}
    private static async Task<List<Dictionary<string,object?>>> Rows(string sql,SqlConnection db,long company,long partner,long user,string? search,CancellationToken token,params (string,object?)[] args){await using var c=Command(sql,db,company,partner,user,search,args);await using var reader=await c.ExecuteReaderAsync(token);var rows=new List<Dictionary<string,object?>>();while(await reader.ReadAsync(token)){var r=new Dictionary<string,object?>();for(var i=0;i<reader.FieldCount;i++)r[reader.GetName(i)]=reader.IsDBNull(i)?null:reader.GetValue(i);rows.Add(r);}return rows;}
    private static SqlCommand Command(string sql,SqlConnection db,long company,long partner,long user,string? search,params (string,object?)[] args){var c=new SqlCommand(sql,db);c.Parameters.AddWithValue("@company",company);c.Parameters.AddWithValue("@partner",partner);c.Parameters.AddWithValue("@user",user);c.Parameters.AddWithValue("@search",search??(object)DBNull.Value);foreach(var(name,value)in args)c.Parameters.AddWithValue(name,value??DBNull.Value);return c;}
}
