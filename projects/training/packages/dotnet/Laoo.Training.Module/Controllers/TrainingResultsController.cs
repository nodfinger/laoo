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
    public async Task<IActionResult> List([FromQuery] int page=1,[FromQuery] int pageSize=30,[FromQuery] string? search=null,CancellationToken token=default)
    {
        if(!Scope(out var company,out var partner,out var user)) return Forbid();
        page=Math.Max(1,page); pageSize=Math.Clamp(pageSize,1,100); await using var db=await Open(token);
        const string where="""
WHERE B.CompanyID=@company AND B.ActivityTypeCode=N'TRAINING'
AND EXISTS(SELECT 1 FROM dbo.TDADProject PR JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=PR.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1 WHERE PR.ProjectCode=N'LAOO_TRAINING' AND PR.IsActive=1 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
AND (U.IsCompanyAdmin=1 OR B.RequesterUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomContact RC JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=B.CompanyID AND UE.EmployeeID=RC.EmployeeID AND UE.UserID=@user AND UE.IsActive=1 WHERE RC.RoomID=B.RoomID AND RC.IsActive=1))
AND (@search IS NULL OR @search=N'' OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%')
""";
        const string joins="""
FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADUser U ON U.UserID=@user AND U.CompanyID=B.CompanyID AND U.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=B.CompanyID AND C.PartnerID=@partner AND C.IsActive=1
""";
        var total=Convert.ToInt64(await Scalar($"SELECT COUNT_BIG(*) {joins} {where}",db,company,partner,user,search,token));
        var rows=await Rows($"""
SELECT B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,MIN(S.StartDateTime) StartDateTime,MAX(S.EndDateTime) EndDateTime,
COUNT(P.BookingParticipantID) Invited,SUM(CASE WHEN P.InvitationStatus=N'ACCEPTED' AND ISNULL(P.IsLateResponse,0)=0 THEN 1 ELSE 0 END) Accepted,SUM(CASE WHEN P.InvitationStatus=N'ACCEPTED' AND ISNULL(P.IsLateResponse,0)=1 THEN 1 ELSE 0 END) LateAccepted,SUM(CASE WHEN P.InvitationStatus=N'PENDING' THEN 1 ELSE 0 END) Pending,SUM(CASE WHEN P.InvitationStatus=N'DECLINED' THEN 1 ELSE 0 END) Declined
{joins} JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID LEFT JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.BookingID=B.BookingID AND P.CompanyID=B.CompanyID {where} GROUP BY B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH ORDER BY MIN(S.StartDateTime) DESC,B.BookingID DESC OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY
""",db,company,partner,user,search,token,("@offset",(page-1)*pageSize),("@pageSize",pageSize));
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
SELECT P.BookingParticipantID,E.EmployeeCode,E.FullName,P.InvitationStatus,ISNULL(P.IsLateResponse,0) IsLateResponse,A.Score,A.MaxScore,A.Passed,A.SubmittedDate,A.StartedDate,
CASE WHEN X.ExamID IS NULL THEN N'NOT_CONFIGURED' WHEN P.InvitationStatus<>N'ACCEPTED' THEN N'NOT_ELIGIBLE' WHEN A.AttemptID IS NULL THEN N'NOT_STARTED' WHEN A.SubmittedDate IS NULL THEN N'IN_PROGRESS' ELSE N'SUBMITTED' END TestStatus
FROM dbo.TDADMeetingRoomBookingParticipant P JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=P.CompanyID
LEFT JOIN dbo.TDTRBookingExam X ON X.CompanyID=P.CompanyID AND X.BookingID=P.BookingID AND X.SectionCode=@section
LEFT JOIN dbo.TDTRBookingExamAttempt A ON A.CompanyID=P.CompanyID AND A.ExamID=X.ExamID AND A.BookingParticipantID=P.BookingParticipantID
WHERE P.CompanyID=@company AND P.BookingID=@booking
ORDER BY CASE WHEN A.Score IS NULL THEN 1 ELSE 0 END,A.Score DESC,A.SubmittedDate,E.FullName,P.BookingParticipantID
""",db,company,partner,user,null,token,("@booking",bookingId),("@section",section));
        return Ok(new {section,eligible=rows.Count(r=>(r["InvitationStatus"] as string)=="ACCEPTED"),notStarted=rows.Count(r=>(r["TestStatus"] as string)=="NOT_STARTED"),inProgress=rows.Count(r=>(r["TestStatus"] as string)=="IN_PROGRESS"),submitted=rows.Count(r=>r["SubmittedDate"] is not null),passed=rows.Count(r=>r["Passed"] is true),failed=rows.Count(r=>r["Passed"] is false),items=rows.Select(r=>new {participantId=r["BookingParticipantID"],code=r["EmployeeCode"],name=r["FullName"],invitationStatus=r["InvitationStatus"],isLateResponse=r["IsLateResponse"] is true,testStatus=r["TestStatus"],score=r["Score"],maxScore=r["MaxScore"],percent=r["Score"] is int score&&r["MaxScore"] is int max?decimal.Round(score*100m/max,2):(decimal?)null,result=r["SubmittedDate"] is null?null:r["Passed"] is true?"PASSED":"FAILED",submittedDate=r["SubmittedDate"]})});
    }

    private static object Booking(Dictionary<string,object?> r)=>new {bookingId=r["BookingID"],bookingNo=r["BookingNo"],subject=r["Subject"],status=r["BookingStatus"],roomCode=r["RoomCode"],roomName=r["RoomNameTH"],startDateTime=r["StartDateTime"],endDateTime=r["EndDateTime"],invited=Convert.ToInt32(r["Invited"]),accepted=Convert.ToInt32(r["Accepted"]),lateAccepted=Convert.ToInt32(r["LateAccepted"]),pending=Convert.ToInt32(r["Pending"]),declined=Convert.ToInt32(r["Declined"])};
    private bool Scope(out long company,out long partner,out long user){company=partner=user=0;return long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("partner_id"),out partner)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&User.FindFirstValue("user_type")=="COMPANY_USER";}
    private async Task<bool> Allowed(SqlConnection db,long company,long partner,long user,long booking,CancellationToken token)=>Convert.ToInt32(await Scalar("""SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADUser U ON U.UserID=@user AND U.CompanyID=B.CompanyID AND U.IsActive=1 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=B.CompanyID AND C.PartnerID=@partner AND C.IsActive=1 WHERE B.CompanyID=@company AND B.BookingID=@booking AND B.ActivityTypeCode=N'TRAINING' AND EXISTS(SELECT 1 FROM dbo.TDADProject PR JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=PR.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1 WHERE PR.ProjectCode=N'LAOO_TRAINING' AND PR.IsActive=1) AND (U.IsCompanyAdmin=1 OR B.RequesterUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomContact RC JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=B.CompanyID AND UE.EmployeeID=RC.EmployeeID AND UE.UserID=@user AND UE.IsActive=1 WHERE RC.RoomID=B.RoomID AND RC.IsActive=1))) THEN 1 ELSE 0 END""",db,company,partner,user,null,token,("@booking",booking)))==1;
    private async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    private static async Task<object?> Scalar(string sql,SqlConnection db,long company,long partner,long user,string? search,CancellationToken token,params (string,object?)[] args){await using var c=Command(sql,db,company,partner,user,search,args);return await c.ExecuteScalarAsync(token);}
    private static async Task<List<Dictionary<string,object?>>> Rows(string sql,SqlConnection db,long company,long partner,long user,string? search,CancellationToken token,params (string,object?)[] args){await using var c=Command(sql,db,company,partner,user,search,args);await using var reader=await c.ExecuteReaderAsync(token);var rows=new List<Dictionary<string,object?>>();while(await reader.ReadAsync(token)){var r=new Dictionary<string,object?>();for(var i=0;i<reader.FieldCount;i++)r[reader.GetName(i)]=reader.IsDBNull(i)?null:reader.GetValue(i);rows.Add(r);}return rows;}
    private static SqlCommand Command(string sql,SqlConnection db,long company,long partner,long user,string? search,params (string,object?)[] args){var c=new SqlCommand(sql,db);c.Parameters.AddWithValue("@company",company);c.Parameters.AddWithValue("@partner",partner);c.Parameters.AddWithValue("@user",user);c.Parameters.AddWithValue("@search",search??(object)DBNull.Value);foreach(var(name,value)in args)c.Parameters.AddWithValue(name,value??DBNull.Value);return c;}
}
