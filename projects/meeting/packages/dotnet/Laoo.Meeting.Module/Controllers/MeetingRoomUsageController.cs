using System.Security.Claims;
using LaooMeetingApi.Security;
using Laoo.Shared.Contracts.Evaluations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize, Route("api/company/meeting-room-usage")]
[RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingRoomUsageController(IConfiguration configuration,IEvaluationSourceCompletedPublisher evaluationPublisher) : ControllerBase
{
    const string Usage="22001", Utilization="24001", NoShow="24002", Feedback="24003";

    [HttpGet]
    public Task<IActionResult> List(DateTime? dateFrom,DateTime? dateTo,string? search,string? status,long? roomId,int page=1,int pageSize=20,CancellationToken token=default)
        => UsageList(dateFrom,dateTo,search,status,roomId,page,pageSize,token);

    [HttpGet("rooms")]
    public async Task<IActionResult> Rooms(CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);
        if(!await Permit(db,Usage,"VIEW",token)&&!await Permit(db,Utilization,"VIEW",token)&&!await Permit(db,NoShow,"VIEW",token))return Forbid();
        var sql=$"""SELECT DISTINCT R.RoomID,R.RoomCode,R.RoomNameTH FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID WHERE B.CompanyID=@company AND (@admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql}) ORDER BY R.RoomCode;""";
        await using var cmd=new SqlCommand(sql,db);Add(cmd,"@company",company);Add(cmd,"@user",user);Add(cmd,"@admin",await Admin(db,company,user,token));
        await using var r=await cmd.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new {roomId=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2)});return Ok(new {items});
    }

    [HttpPut("{bookingId:long}/{slotId:long}/check-in")]
    public Task<IActionResult> CheckIn(long bookingId,long slotId,CancellationToken token)=>ChangeSafe(bookingId,slotId,false,null,token);

    [HttpPut("{bookingId:long}/{slotId:long}/return")]
    public Task<IActionResult> Return(long bookingId,long slotId,RoomReturnRequest request,CancellationToken token)=>ChangeSafe(bookingId,slotId,true,Clean(request.Remark),token);

    [HttpGet("reports/utilization")]
    public async Task<IActionResult> UtilizationReport(DateTime? dateFrom,DateTime? dateTo,long? roomId,int page=1,int pageSize=20,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);if(!await Permit(db,Utilization,"VIEW",token))return Forbid();
        var (from,to)=Dates(dateFrom,dateTo);page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);var admin=await Admin(db,company,user,token);
        var where=$"""WHERE B.CompanyID=@company AND B.BookingStatus='APPROVED' AND S.StartDateTime>=@from AND S.StartDateTime<DATEADD(day,1,@to) AND (@room IS NULL OR B.RoomID=@room) AND (@admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql})""";
        var joins=$"""FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID LEFT JOIN dbo.TDADMeetingRoomBookingSlotUsage U ON U.CompanyID=S.CompanyID AND U.BookingSlotID=S.BookingSlotID {where}""";
        await using var count=new SqlCommand($"SELECT COUNT_BIG(*) FROM (SELECT B.RoomID,CAST(S.StartDateTime AS date) D {joins} GROUP BY B.RoomID,CAST(S.StartDateTime AS date)) X",db);Bind(count,company,user,admin,from,to,roomId);var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var sum=new SqlCommand($"SELECT COUNT_BIG(*),COALESCE(SUM(DATEDIFF(minute,S.StartDateTime,S.EndDateTime)),0),SUM(CASE WHEN U.BookingSlotUsageID IS NULL THEN 0 ELSE 1 END),SUM(CASE WHEN U.ReturnDate IS NULL THEN 0 ELSE 1 END) {joins}",db);Bind(sum,company,user,admin,from,to,roomId);await using var sr=await sum.ExecuteReaderAsync(token);await sr.ReadAsync(token);var summary=new {bookingSlots=Number(sr,0),scheduledMinutes=Number(sr,1),checkedIn=Number(sr,2),returned=Number(sr,3)};await sr.DisposeAsync();
        await using var data=new SqlCommand($"""SELECT CAST(S.StartDateTime AS date),B.RoomID,R.RoomCode,R.RoomNameTH,COUNT_BIG(*),SUM(DATEDIFF(minute,S.StartDateTime,S.EndDateTime)),SUM(CASE WHEN U.BookingSlotUsageID IS NULL THEN 0 ELSE 1 END),SUM(CASE WHEN U.ReturnDate IS NULL THEN 0 ELSE 1 END),SUM(CASE WHEN U.BookingSlotUsageID IS NULL THEN 0 WHEN DATEDIFF(minute,U.CheckInDate,COALESCE(U.ReturnDate,CASE WHEN GETDATE()<S.EndDateTime THEN GETDATE() ELSE S.EndDateTime END))<0 THEN 0 ELSE DATEDIFF(minute,U.CheckInDate,COALESCE(U.ReturnDate,CASE WHEN GETDATE()<S.EndDateTime THEN GETDATE() ELSE S.EndDateTime END)) END) {joins} GROUP BY CAST(S.StartDateTime AS date),B.RoomID,R.RoomCode,R.RoomNameTH ORDER BY CAST(S.StartDateTime AS date) DESC,R.RoomCode OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;""",db);Bind(data,company,user,admin,from,to,roomId);Add(data,"@offset",(page-1)*pageSize);Add(data,"@pageSize",pageSize);await using var r=await data.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new {date=r.GetDateTime(0),roomId=r.GetInt64(1),roomCode=r.GetString(2),roomName=r.GetString(3),bookingSlots=Number(r,4),scheduledMinutes=Number(r,5),checkedIn=Number(r,6),returned=Number(r,7),actualMinutes=Number(r,8)});return Ok(new {items,total,page,pageSize,summary});
    }

    [HttpGet("reports/no-show")]
    public async Task<IActionResult> NoShowReport(DateTime? dateFrom,DateTime? dateTo,long? roomId,string? search,int page=1,int pageSize=20,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);if(!await Permit(db,NoShow,"VIEW",token))return Forbid();
        var (from,to)=Dates(dateFrom,dateTo);page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);var admin=await Admin(db,company,user,token);var term=Clean(search);
        var baseSql=$"""FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.CompanyID=B.CompanyID AND P.BookingID=B.BookingID AND P.InvitationStatus='ACCEPTED' JOIN dbo.TDADEmployee E ON E.CompanyID=P.CompanyID AND E.EmployeeID=P.EmployeeID AND E.IsActive=1 LEFT JOIN dbo.TDADOrganizationUnit D ON D.CompanyID=E.CompanyID AND D.OrgUnitID=E.DepartmentOrgUnitID LEFT JOIN dbo.TDADMeetingParticipantCheckIn C ON C.CompanyID=B.CompanyID AND C.BookingParticipantID=P.BookingParticipantID AND C.BookingSlotID=S.BookingSlotID WHERE B.CompanyID=@company AND B.BookingStatus='APPROVED' AND S.EndDateTime<=GETDATE() AND S.StartDateTime>=@from AND S.StartDateTime<DATEADD(day,1,@to) AND (@room IS NULL OR B.RoomID=@room) AND (@term IS NULL OR B.BookingNo LIKE @term OR B.Subject LIKE @term OR E.EmployeeCode LIKE @term OR E.FullName LIKE @term) AND (@admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql})""";
        await using var count=new SqlCommand($"SELECT COUNT_BIG(*) {baseSql} AND C.ParticipantCheckInID IS NULL",db);Bind(count,company,user,admin,from,to,roomId,term);var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var summaryCmd=new SqlCommand($"SELECT COUNT_BIG(*),SUM(CASE WHEN C.ParticipantCheckInID IS NULL THEN 1 ELSE 0 END) {baseSql}",db);Bind(summaryCmd,company,user,admin,from,to,roomId,term);await using var sr=await summaryCmd.ExecuteReaderAsync(token);await sr.ReadAsync(token);var summary=new {accepted=Number(sr,0),noShow=Number(sr,1)};await sr.DisposeAsync();
        await using var data=new SqlCommand($"""SELECT P.BookingParticipantID,S.BookingSlotID,E.EmployeeCode,E.FullName,D.NameTH,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,S.StartDateTime,S.EndDateTime {baseSql} AND C.ParticipantCheckInID IS NULL ORDER BY S.StartDateTime DESC,E.FullName OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;""",db);Bind(data,company,user,admin,from,to,roomId,term);Add(data,"@offset",(page-1)*pageSize);Add(data,"@pageSize",pageSize);await using var r=await data.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new {participantId=r.GetInt64(0),slotId=r.GetInt64(1),employeeCode=Text(r,2),name=r.GetString(3),department=Text(r,4),bookingNo=r.GetString(5),subject=r.GetString(6),roomCode=r.GetString(7),roomName=r.GetString(8),startDateTime=r.GetDateTime(9),endDateTime=r.GetDateTime(10)});return Ok(new {items,total,page,pageSize,summary});
    }

    [HttpGet("reports/feedback")]
    public async Task<IActionResult> FeedbackReport(DateTime? dateFrom,DateTime? dateTo,long? roomId,string? search,int page=1,int pageSize=20,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);
        if(!await Permit(db,Feedback,"VIEW",token))return Forbid();
        var (from,to)=Dates(dateFrom,dateTo);
        page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);
        var admin=await Admin(db,company,user,token);
        var term=Clean(search);
        var scope=$"(@admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql})";
        var where=$"""WHERE R.CompanyID=@company AND R.SourceProjectCode='LAOO_MEETING' AND R.SourceType='MEETING_ROOM' AND B.CompanyID=R.CompanyID AND (@room IS NULL OR B.RoomID=@room) AND EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID AND S.StartDateTime>=@from AND S.StartDateTime<DATEADD(day,1,@to)) AND (@term IS NULL OR R.RoundNo LIKE @term OR R.RoundName LIKE @term OR R.ReferenceTitleSnapshot LIKE @term OR B.BookingNo LIKE @term OR B.Subject LIKE @term) AND {scope}""";
        var fromJoins="FROM dbo.TDEVRound R JOIN dbo.TDADMeetingRoomBooking B ON B.CompanyID=R.CompanyID AND B.BookingID=R.ReferenceEntityID JOIN dbo.TDADMeetingRoom RM ON RM.CompanyID=B.CompanyID AND RM.RoomID=B.RoomID";
        var joins=$"{fromJoins} {where}";
        await using var count=new SqlCommand($"SELECT COUNT_BIG(*) {joins}",db);Bind(count,company,user,admin,from,to,roomId,term);var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var summaryCmd=new SqlCommand($"""SELECT COUNT_BIG(*),COALESCE(SUM(A.Assigned),0),COALESCE(SUM(A.Submitted),0),CASE WHEN SUM(COALESCE(A.Submitted,0))>=5 THEN AVG(CASE WHEN A.Submitted>=5 THEN V.AverageRating END) END {fromJoins} OUTER APPLY(SELECT COUNT_BIG(*) Assigned,SUM(CASE WHEN AssignmentStatus='SUBMITTED' THEN 1 ELSE 0 END) Submitted FROM dbo.TDEVRoundRespondent RS WHERE RS.CompanyID=R.CompanyID AND RS.EvaluationRoundID=R.EvaluationRoundID) A OUTER APPLY(SELECT AVG(CAST(ANS.RatingValue AS decimal(8,2))) AverageRating FROM dbo.TDEVRoundAnswer ANS JOIN dbo.TDEVRoundSubmission SUB ON SUB.EvaluationRoundSubmissionID=ANS.EvaluationRoundSubmissionID WHERE ANS.CompanyID=R.CompanyID AND SUB.EvaluationRoundID=R.EvaluationRoundID AND ANS.RatingValue IS NOT NULL) V {where}""",db);Bind(summaryCmd,company,user,admin,from,to,roomId,term);await using var sr=await summaryCmd.ExecuteReaderAsync(token);await sr.ReadAsync(token);var summary=new{rounds=Number(sr,0),eligible=Number(sr,1),submitted=Number(sr,2),averageRating=sr.IsDBNull(3)?(decimal?)null:sr.GetDecimal(3)};await sr.DisposeAsync();
        await using var data=new SqlCommand($"""SELECT R.EvaluationRoundID,R.RoundNo,R.RoundName,R.StatusCode,B.BookingNo,B.Subject,RM.RoomCode,RM.RoomNameTH,(SELECT MIN(S.StartDateTime) FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID),A.Assigned,A.Submitted,CASE WHEN A.Submitted>=5 THEN V.AverageRating END {fromJoins} OUTER APPLY(SELECT COUNT_BIG(*) Assigned,SUM(CASE WHEN AssignmentStatus='SUBMITTED' THEN 1 ELSE 0 END) Submitted FROM dbo.TDEVRoundRespondent RS WHERE RS.CompanyID=R.CompanyID AND RS.EvaluationRoundID=R.EvaluationRoundID) A OUTER APPLY(SELECT AVG(CAST(ANS.RatingValue AS decimal(8,2))) AverageRating FROM dbo.TDEVRoundAnswer ANS JOIN dbo.TDEVRoundSubmission SUB ON SUB.EvaluationRoundSubmissionID=ANS.EvaluationRoundSubmissionID WHERE ANS.CompanyID=R.CompanyID AND SUB.EvaluationRoundID=R.EvaluationRoundID AND ANS.RatingValue IS NOT NULL) V {where} ORDER BY (CASE WHEN A.Assigned>COALESCE(A.Submitted,0) THEN 0 ELSE 1 END),R.CreateDate DESC OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;""",db);Bind(data,company,user,admin,from,to,roomId,term);Add(data,"@offset",(page-1)*pageSize);Add(data,"@pageSize",pageSize);await using var r=await data.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new{roundId=r.GetInt64(0),roundNo=r.GetString(1),roundName=r.GetString(2),status=r.GetString(3),bookingNo=r.GetString(4),subject=r.GetString(5),roomCode=r.GetString(6),roomName=r.GetString(7),meetingDate=Date(r,8),eligible=Number(r,9),submitted=Number(r,10),averageRating=r.IsDBNull(11)?(decimal?)null:r.GetDecimal(11)});return Ok(new{items,total,page,pageSize,summary});
    }

    async Task<IActionResult> UsageList(DateTime? dateFrom,DateTime? dateTo,string? search,string? status,long? roomId,int page,int pageSize,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Permit(db,Usage,"VIEW",token))return Forbid();
        var (from,to)=Dates(dateFrom,dateTo);page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);var admin=await Admin(db,company,user,token);var term=Clean(search);var state=Clean(status)?.ToUpperInvariant();var now=$"""CASE WHEN U.ReturnDate IS NOT NULL THEN 'RETURNED' WHEN U.BookingSlotUsageID IS NOT NULL THEN 'IN_USE' WHEN S.EndDateTime<=GETDATE() THEN 'EXPIRED' WHEN S.StartDateTime<=GETDATE() THEN 'READY' ELSE 'WAITING' END""";
        var baseSql=$"""FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID LEFT JOIN dbo.TDADMeetingRoomBookingSlotUsage U ON U.CompanyID=S.CompanyID AND U.BookingSlotID=S.BookingSlotID WHERE B.CompanyID=@company AND B.BookingStatus='APPROVED' AND S.StartDateTime>=@from AND S.StartDateTime<DATEADD(day,1,@to) AND (@room IS NULL OR B.RoomID=@room) AND (@term IS NULL OR B.BookingNo LIKE @term OR B.Subject LIKE @term OR R.RoomCode LIKE @term OR R.RoomNameTH LIKE @term) AND (@admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql}) AND (@status IS NULL OR {now}=@status)""";
        await using var count=new SqlCommand($"SELECT COUNT_BIG(*) {baseSql}",db);Bind(count,company,user,admin,from,to,roomId,term,state);var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var data=new SqlCommand($"""SELECT B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,S.BookingSlotID,S.StartDateTime,S.EndDateTime,U.CheckInDate,U.CheckInByUserID,U.ReturnDate,U.ReturnByUserID,U.ReturnRemark,{now},CASE WHEN @edit=1 AND (@admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql}) THEN 1 ELSE 0 END {baseSql} ORDER BY CASE WHEN {now}='READY' THEN 0 WHEN {now}='IN_USE' THEN 1 WHEN {now}='WAITING' THEN 2 ELSE 3 END,S.StartDateTime OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;""",db);Bind(data,company,user,admin,from,to,roomId,term,state);Add(data,"@edit",await Permit(db,Usage,"EDIT",token));Add(data,"@offset",(page-1)*pageSize);Add(data,"@pageSize",pageSize);await using var r=await data.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new {bookingId=r.GetInt64(0),bookingNo=r.GetString(1),subject=r.GetString(2),roomCode=r.GetString(3),roomName=r.GetString(4),slotId=r.GetInt64(5),startDateTime=r.GetDateTime(6),endDateTime=r.GetDateTime(7),checkInDate=Date(r,8),returnDate=Date(r,10),returnRemark=Text(r,12),status=r.GetString(13),canManage=r.GetInt32(14)==1});return Ok(new {items,total,page,pageSize});
    }

    async Task<IActionResult> Change(long booking,long slot,bool returning,string? remark,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Permit(db,Usage,"EDIT",token))return Forbid();await using var tx=await db.BeginTransactionAsync(token);var admin=await Admin(db,company,user,token);var scope=$"(@admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql})";
        var sql=returning?$"""UPDATE U SET ReturnDate=SYSUTCDATETIME(),ReturnByUserID=@user,ReturnRemark=@remark OUTPUT INSERTED.CheckInDate,INSERTED.ReturnDate FROM dbo.TDADMeetingRoomBookingSlotUsage U JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=U.CompanyID AND S.BookingSlotID=U.BookingSlotID JOIN dbo.TDADMeetingRoomBooking B ON B.CompanyID=S.CompanyID AND B.BookingID=S.BookingID WHERE U.CompanyID=@company AND U.BookingID=@booking AND U.BookingSlotID=@slot AND U.ReturnDate IS NULL AND B.BookingStatus='APPROVED' AND {scope};""":$"""INSERT dbo.TDADMeetingRoomBookingSlotUsage(CompanyID,BookingID,BookingSlotID,CheckInByUserID) OUTPUT INSERTED.CheckInDate,INSERTED.ReturnDate SELECT @company,B.BookingID,S.BookingSlotID,@user FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID WHERE B.CompanyID=@company AND B.BookingID=@booking AND S.BookingSlotID=@slot AND B.BookingStatus='APPROVED' AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE() AND {scope} AND NOT EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingSlotUsage U WITH(UPDLOCK,HOLDLOCK) WHERE U.CompanyID=@company AND U.BookingSlotID=@slot);""";
        await using var cmd=new SqlCommand(sql,db,(SqlTransaction)tx);Add(cmd,"@company",company);Add(cmd,"@booking",booking);Add(cmd,"@slot",slot);Add(cmd,"@user",user);Add(cmd,"@admin",admin);Add(cmd,"@remark",remark);await using var r=await cmd.ExecuteReaderAsync(token);if(!await r.ReadAsync(token))return Conflict(Error(returning?"คืนห้องไม่ได้":"เช็กอินห้องไม่ได้",returning?"รายการอาจคืนห้องแล้ว หรือผู้ใช้ไม่มีสิทธิ์จัดการรอบนี้":"ต้องเป็นรอบที่เริ่มแล้ว ยังไม่สิ้นสุด และยังไม่เคยเช็กอิน"));var checkIn=r.GetDateTime(0);var returned=Date(r,1);await r.DisposeAsync();await tx.CommitAsync(token);if(returning)await PublishRoomEvaluation(company,booking,returned??DateTime.UtcNow,token);return Ok(new {bookingId=booking,slotId=slot,checkInDate=checkIn,returnDate=returned});
    }

    async Task<IActionResult> ChangeSafe(long booking,long slot,bool returning,string? remark,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);
        if(!await Permit(db,Usage,"EDIT",token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var admin=await Admin(db,company,user,token);
        var scope="(@admin=1 OR B.RequesterUserID=@user OR "+MeetingRoomAdminAccess.BookingRoomSql+")";
        var sql=returning
            ? "UPDATE U SET ReturnDate=SYSUTCDATETIME(),ReturnByUserID=@user,ReturnRemark=@remark FROM dbo.TDADMeetingRoomBookingSlotUsage U JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=U.CompanyID AND S.BookingSlotID=U.BookingSlotID JOIN dbo.TDADMeetingRoomBooking B ON B.CompanyID=S.CompanyID AND B.BookingID=S.BookingID WHERE U.CompanyID=@company AND U.BookingID=@booking AND U.BookingSlotID=@slot AND U.ReturnDate IS NULL AND B.BookingStatus='APPROVED' AND "+scope
            : "INSERT dbo.TDADMeetingRoomBookingSlotUsage(CompanyID,BookingID,BookingSlotID,CheckInByUserID) SELECT @company,B.BookingID,S.BookingSlotID,@user FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID WHERE B.CompanyID=@company AND B.BookingID=@booking AND S.BookingSlotID=@slot AND B.BookingStatus='APPROVED' AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE() AND "+scope+" AND NOT EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingSlotUsage U WITH(UPDLOCK,HOLDLOCK) WHERE U.CompanyID=@company AND U.BookingSlotID=@slot)";
        await using var cmd=new SqlCommand(sql,db,tx);
        Add(cmd,"@company",company);Add(cmd,"@booking",booking);Add(cmd,"@slot",slot);Add(cmd,"@user",user);Add(cmd,"@admin",admin);Add(cmd,"@remark",remark);
        if(await cmd.ExecuteNonQueryAsync(token)!=1)
        {
            await tx.RollbackAsync(token);
            return Conflict(Error(returning?"คืนห้องไม่ได้":"เช็กอินห้องไม่ได้",returning?"รายการอาจคืนห้องแล้ว หรือผู้ใช้ไม่มีสิทธิ์จัดการรอบนี้":"ต้องเป็นรอบที่เริ่มแล้ว ยังไม่สิ้นสุด และยังไม่เคยเช็กอิน"));
        }
        await using var saved=new SqlCommand("SELECT CheckInDate,ReturnDate FROM dbo.TDADMeetingRoomBookingSlotUsage WHERE CompanyID=@company AND BookingID=@booking AND BookingSlotID=@slot",db,tx);
        Add(saved,"@company",company);Add(saved,"@booking",booking);Add(saved,"@slot",slot);
        await using var row=await saved.ExecuteReaderAsync(token);
        if(!await row.ReadAsync(token))
        {
            await tx.RollbackAsync(token);
            return Conflict(Error(returning?"คืนห้องไม่ได้":"เช็กอินห้องไม่ได้","ไม่พบข้อมูลการใช้งานห้องหลังบันทึก"));
        }
        var checkIn=row.GetDateTime(0);
        var returned=Date(row,1);
        await row.DisposeAsync();
        await tx.CommitAsync(token);
        if(returning)await PublishRoomEvaluation(company,booking,returned??DateTime.UtcNow,token);
        return Ok(new {bookingId=booking,slotId=slot,checkInDate=checkIn,returnDate=returned});
    }

    async Task PublishRoomEvaluation(long company,long booking,DateTime completedAt,CancellationToken token)
    {
        try{
            await using var db=await Open(token);
            await using var head=new SqlCommand("SELECT BookingNo,Subject,TrainingInstructorID,TrainingInstructorNameSnapshot FROM dbo.TDADMeetingRoomBooking WHERE CompanyID=@company AND BookingID=@booking AND BookingStatus='APPROVED'",db);Add(head,"@company",company);Add(head,"@booking",booking);await using var record=await head.ExecuteReaderAsync(token);if(!await record.ReadAsync(token))return;var title=$"{record.GetString(0)} | {record.GetString(1)}";var instructorId=record.IsDBNull(2)?(long?)null:record.GetInt64(2);var instructorName=record.IsDBNull(3)?null:record.GetString(3);await record.DisposeAsync();
            await using var users=new SqlCommand("SELECT DISTINCT UE.UserID FROM dbo.TDADMeetingRoomBookingParticipant P JOIN dbo.TDADMeetingParticipantCheckIn C ON C.CompanyID=P.CompanyID AND C.BookingParticipantID=P.BookingParticipantID JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=P.CompanyID AND UE.EmployeeID=P.EmployeeID AND UE.IsActive=1 JOIN dbo.TDADUser U ON U.CompanyID=UE.CompanyID AND U.UserID=UE.UserID AND U.IsActive=1 WHERE P.CompanyID=@company AND P.BookingID=@booking AND P.InvitationStatus='ACCEPTED'",db);Add(users,"@company",company);Add(users,"@booking",booking);await using var rows=await users.ExecuteReaderAsync(token);var respondentIds=new List<long>();while(await rows.ReadAsync(token))respondentIds.Add(rows.GetInt64(0));await rows.DisposeAsync();if(respondentIds.Count==0)return;
            await using var selections=new SqlCommand("SELECT EvaluationSourceType,EvaluationTemplateID FROM dbo.TDADMeetingRoomBookingEvaluation WHERE CompanyID=@company AND BookingID=@booking AND IsActive=1",db);Add(selections,"@company",company);Add(selections,"@booking",booking);await using var selected=await selections.ExecuteReaderAsync(token);var templates=new List<(string Source,long Template)>();while(await selected.ReadAsync(token))templates.Add((selected.GetString(0),selected.GetInt64(1)));await selected.DisposeAsync();
            foreach(var item in templates){if(item.Source==EvaluationSourceTypes.TrainingInstructor&&instructorId is null&&string.IsNullOrWhiteSpace(instructorName))continue;var project=item.Source==EvaluationSourceTypes.MeetingRoom?"LAOO_MEETING":"LAOO_TRAINING";var referenceTitle=item.Source==EvaluationSourceTypes.TrainingInstructor?$"{title} | {instructorName}":title;await evaluationPublisher.PublishAsync(new EvaluationSourceCompletedContract(company,project,item.Source,booking,referenceTitle,completedAt.ToUniversalTime(),respondentIds,item.Template),token);}
        }catch{}
    }

    static (DateTime from,DateTime to) Dates(DateTime? from,DateTime? to){var end=(to??DateTime.Today).Date;var start=(from??end.AddDays(-30)).Date;return start>end?(end,start):(start,end);}
    Task<bool> Permit(SqlConnection db,string screen,string action,CancellationToken token)=>MeetingFoodPlanAccess.Allowed(db,User,action,token,screen);
    async Task<bool> Admin(SqlConnection db,long company,long user,CancellationToken token){await using var c=new SqlCommand("SELECT IsCompanyAdmin FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@user AND IsActive=1",db);Add(c,"@company",company);Add(c,"@user",user);var v=await c.ExecuteScalarAsync(token);return v is not null&&v!=DBNull.Value&&Convert.ToBoolean(v);}
    static void Bind(SqlCommand c,long company,long user,bool admin,DateTime from,DateTime to,long? room,string? term=null,string? status=null){Add(c,"@company",company);Add(c,"@user",user);Add(c,"@admin",admin);Add(c,"@from",from);Add(c,"@to",to);Add(c,"@room",room);Add(c,"@term",term is null?null:$"%{term}%");Add(c,"@status",status);}
    bool Scope(out long company,out long user){company=0;user=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out company)&&company>0&&long.TryParse(User.FindFirstValue("user_id"),out user)&&user>0;}
    async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    static void Add(SqlCommand c,string n,object? v)=>c.Parameters.AddWithValue(n,v??DBNull.Value);
    static string? Clean(string? s)=>string.IsNullOrWhiteSpace(s)?null:s.Trim();
    static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetValue(i)?.ToString();
    static DateTime? Date(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetDateTime(i);
    static long Number(SqlDataReader r,int i)=>r.IsDBNull(i)?0:Convert.ToInt64(r.GetValue(i));
    static object Error(string message,string description)=>new {message,description};
}
public sealed record RoomReturnRequest(string? Remark);
