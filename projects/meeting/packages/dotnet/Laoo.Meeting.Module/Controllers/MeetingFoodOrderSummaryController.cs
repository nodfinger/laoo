using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using LaooMeetingApi.Security;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize, Route("api/company/meeting-food-order-summaries")]
[RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingFoodOrderSummaryController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "21006";

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search,[FromQuery] DateOnly? dateFrom,[FromQuery] DateOnly? dateTo,
        [FromQuery] int page=1,[FromQuery] int pageSize=20,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user)) return Forbid();
        if(page<1 || pageSize is <1 or >100) return BadRequest(Error("ตัวกรองไม่ถูกต้อง","หน้าต้องเริ่มจาก 1 และจำนวนต่อหน้าต้องอยู่ระหว่าง 1 ถึง 100"));
        var from=dateFrom??DateOnly.FromDateTime(DateTime.Today);
        var to=dateTo??from.AddDays(30);
        if(to<from || to.DayNumber-from.DayNumber>366) return BadRequest(Error("ช่วงวันที่ไม่ถูกต้อง","วันที่สิ้นสุดต้องไม่น้อยกว่าวันที่เริ่ม และเลือกได้ไม่เกิน 366 วัน"));
        search=string.IsNullOrWhiteSpace(search)?null:search.Trim();
        await using var db=await Open(token);
        if(!await MeetingFoodPlanAccess.Allowed(db,User,"VIEW",token,ScreenCode)) return Forbid();
        if(!await Ready(db,token)) return Ok(new {available=false,total=0,page,pageSize,items=Array.Empty<object>()});
        var where=$"""
WHERE B.CompanyID=@company
 AND EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingSlot SX WHERE SX.CompanyID=B.CompanyID AND SX.BookingID=B.BookingID
   AND SX.StartDateTime<DATEADD(day,1,CAST(@to AS datetime2)) AND SX.EndDateTime>=CAST(@from AS datetime2))
 AND (B.BookingStatus='APPROVED' OR (B.BookingStatus='CANCELLED' AND EXISTS(
   SELECT 1 FROM dbo.TDADMeetingBookingFoodOrder HX
   JOIN dbo.TDADMeetingBookingFoodOrderDetail DX ON DX.BookingFoodOrderID=HX.BookingFoodOrderID
   WHERE HX.CompanyID=B.CompanyID AND HX.BookingID=B.BookingID)))
 AND EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodOption OX WHERE OX.CompanyID=B.CompanyID AND OX.BookingID=B.BookingID)
 AND (@search IS NULL OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%'
   OR R.RoomCode LIKE N'%'+@search+N'%' OR R.RoomNameTH LIKE N'%'+@search+N'%')
""";
        await using var count=new SqlCommand($"""
SELECT COUNT_BIG(1) FROM dbo.TDADMeetingRoomBooking B
JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID
{where};
""",db);
        Bind(count,company,user,search,from,to);
        var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var cmd=new SqlCommand($"""
SELECT B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,
 (SELECT MIN(S.StartDateTime) FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID),
 (SELECT MAX(S.EndDateTime) FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID),
 ISNULL(A.OrderedParticipantCount,0),ISNULL(A.OrderedQuantity,0)
FROM dbo.TDADMeetingRoomBooking B
JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID
OUTER APPLY(
 SELECT COUNT(DISTINCT H.BookingParticipantID) OrderedParticipantCount,ISNULL(SUM(D.Quantity),0) OrderedQuantity
 FROM dbo.TDADMeetingBookingFoodOrder H
 JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID
 JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.CompanyID=H.CompanyID AND P.BookingParticipantID=H.BookingParticipantID
 WHERE H.CompanyID=B.CompanyID AND H.BookingID=B.BookingID AND P.InvitationStatus IN ('PENDING','ACCEPTED')
) A
{where}
ORDER BY 7,B.BookingID OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""",db);
        Bind(cmd,company,user,search,from,to);cmd.Parameters.AddWithValue("@offset",(page-1)*pageSize);cmd.Parameters.AddWithValue("@take",pageSize);
        await using var reader=await cmd.ExecuteReaderAsync(token);var items=new List<Dictionary<string,object?>>();var bookingIds=new List<long>();
        while(await reader.ReadAsync(token))
        {
            var bookingId=reader.GetInt64(0);bookingIds.Add(bookingId);
            items.Add(new Dictionary<string,object?> {
                ["bookingId"]=bookingId,["bookingNo"]=Text(reader,1),["subject"]=reader.GetString(2),["status"]=reader.GetString(3),
                ["roomCode"]=reader.GetString(4),["roomName"]=reader.GetString(5),["startDateTime"]=reader.GetDateTime(6),["endDateTime"]=reader.GetDateTime(7),
                ["orderedParticipantCount"]=reader.GetInt32(8),["orderedQuantity"]=reader.GetInt32(9)});
        }
        await reader.CloseAsync();
        var foods=await FoodSummaries(db,company,bookingIds,token);
        foreach(var item in items) item["foods"]=foods.TryGetValue((long)item["bookingId"]!,out var rows)?rows:Array.Empty<object>();
        return Ok(new {available=true,total,page,pageSize,items});
    }

    [HttpGet("{bookingId:long}")]
    public async Task<IActionResult> Get(long bookingId,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Forbid();
        await using var db=await Open(token);
        if(!await MeetingFoodPlanAccess.Allowed(db,User,"VIEW",token,ScreenCode)) return Forbid();
        if(!await Ready(db,token)) return StatusCode(503,Error("ระบบสรุปอาหารยังไม่พร้อม","ยังไม่ได้ติดตั้งโครงสร้างคำสั่งอาหาร กรุณาติดต่อผู้ดูแลระบบ"));
        await using var headerCommand=new SqlCommand($"""
SELECT B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,MIN(S.StartDateTime),MAX(S.EndDateTime)
FROM dbo.TDADMeetingRoomBooking B
JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID
WHERE B.CompanyID=@company AND B.BookingID=@booking
 AND (B.BookingStatus='APPROVED' OR (B.BookingStatus='CANCELLED' AND EXISTS(
   SELECT 1 FROM dbo.TDADMeetingBookingFoodOrder HX JOIN dbo.TDADMeetingBookingFoodOrderDetail DX ON DX.BookingFoodOrderID=HX.BookingFoodOrderID
   WHERE HX.CompanyID=B.CompanyID AND HX.BookingID=B.BookingID)))
GROUP BY B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH;
""",db);
        headerCommand.Parameters.AddWithValue("@company",company);headerCommand.Parameters.AddWithValue("@user",user);headerCommand.Parameters.AddWithValue("@booking",bookingId);
        await using var headerReader=await headerCommand.ExecuteReaderAsync(token);
        if(!await headerReader.ReadAsync(token)) return Forbid();
        var header=new {bookingId=headerReader.GetInt64(0),bookingNo=Text(headerReader,1),subject=headerReader.GetString(2),status=headerReader.GetString(3),
            roomCode=headerReader.GetString(4),roomName=headerReader.GetString(5),startDateTime=headerReader.GetDateTime(6),endDateTime=headerReader.GetDateTime(7)};
        await headerReader.CloseAsync();
        await using var cmd=new SqlCommand("""
SELECT F.FoodID,F.FoodCode,F.FoodNameTH,F.FoodTypeCode,T.Name,ISNULL(A.OrderedParticipantCount,0),ISNULL(A.OrderedQuantity,0)
FROM dbo.TDADMeetingBookingFoodOption O
JOIN dbo.TDADMeetingFood F ON F.CompanyID=O.CompanyID AND F.FoodID=O.FoodID
OUTER APPLY(SELECT TOP(1) M.Name,M.Seq FROM dbo.TDSTMaster M
 WHERE M.MasterGroupCode='011' AND M.MasterCode=F.FoodTypeCode AND M.IsActive=1 AND M.OwnerType='C' AND M.OwnerCompanyID=@company) T
OUTER APPLY(
 SELECT COUNT(DISTINCT H.BookingParticipantID) OrderedParticipantCount,ISNULL(SUM(D.Quantity),0) OrderedQuantity
 FROM dbo.TDADMeetingBookingFoodOrder H
 JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID AND D.FoodID=F.FoodID
 JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.CompanyID=H.CompanyID AND P.BookingParticipantID=H.BookingParticipantID
 WHERE H.CompanyID=O.CompanyID AND H.BookingID=O.BookingID AND P.InvitationStatus IN ('PENDING','ACCEPTED')
) A
WHERE O.CompanyID=@company AND O.BookingID=@booking
ORDER BY ISNULL(T.Seq,0),F.FoodNameTH,F.FoodCode;
""",db);
        cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@booking",bookingId);
        await using var reader=await cmd.ExecuteReaderAsync(token);var items=new List<object>();
        while(await reader.ReadAsync(token)) items.Add(new {foodId=reader.GetInt64(0),code=reader.GetString(1),nameTh=reader.GetString(2),
            foodTypeCode=reader.GetString(3),foodTypeName=Text(reader,4),orderedParticipantCount=reader.GetInt32(5),orderedQuantity=reader.GetInt32(6)});
        return Ok(new {header,items});
    }

    private bool Scope(out long company,out long user)
    {
        company=0;user=0;
        return User.FindFirstValue("user_type")=="COMPANY_USER"
            && long.TryParse(User.FindFirstValue("company_id"),out company) && company>0
            && long.TryParse(User.FindFirstValue("user_id"),out user) && user>0;
    }
    private async Task<SqlConnection> Open(CancellationToken token) { var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db; }
    private static async Task<bool> Ready(SqlConnection db,CancellationToken token)
    {
        await using var cmd=new SqlCommand("""
SELECT CASE WHEN OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrder',N'U') IS NOT NULL
 AND OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrderDetail',N'U') IS NOT NULL THEN 1 ELSE 0 END
""",db);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }
    private static async Task<Dictionary<long,List<object>>> FoodSummaries(SqlConnection db,long company,IReadOnlyList<long> bookingIds,CancellationToken token)
    {
        var result=new Dictionary<long,List<object>>();
        if(bookingIds.Count==0) return result;
        var ids=string.Join(',',bookingIds.Select((_,index)=>$"@booking{index}"));
        await using var cmd=new SqlCommand($"""
SELECT O.BookingID,F.FoodID,F.FoodCode,F.FoodNameTH,T.Name,ISNULL(A.OrderedParticipantCount,0),ISNULL(A.OrderedQuantity,0)
FROM dbo.TDADMeetingBookingFoodOption O
JOIN dbo.TDADMeetingFood F ON F.CompanyID=O.CompanyID AND F.FoodID=O.FoodID
OUTER APPLY(SELECT TOP(1) M.Name,M.Seq FROM dbo.TDSTMaster M
 WHERE M.MasterGroupCode='011' AND M.MasterCode=F.FoodTypeCode AND M.IsActive=1 AND M.OwnerType='C' AND M.OwnerCompanyID=@company) T
OUTER APPLY(
 SELECT COUNT(DISTINCT H.BookingParticipantID) OrderedParticipantCount,ISNULL(SUM(D.Quantity),0) OrderedQuantity
 FROM dbo.TDADMeetingBookingFoodOrder H
 JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID AND D.FoodID=F.FoodID
 JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.CompanyID=H.CompanyID AND P.BookingParticipantID=H.BookingParticipantID
 WHERE H.CompanyID=O.CompanyID AND H.BookingID=O.BookingID AND P.InvitationStatus IN ('PENDING','ACCEPTED')
) A
WHERE O.CompanyID=@company AND O.BookingID IN ({ids})
ORDER BY O.BookingID,ISNULL(T.Seq,0),F.FoodNameTH,F.FoodCode;
""",db);
        cmd.Parameters.AddWithValue("@company",company);
        for(var index=0;index<bookingIds.Count;index++) cmd.Parameters.AddWithValue($"@booking{index}",bookingIds[index]);
        await using var reader=await cmd.ExecuteReaderAsync(token);
        while(await reader.ReadAsync(token))
        {
            var bookingId=reader.GetInt64(0);
            if(!result.TryGetValue(bookingId,out var rows)) result[bookingId]=rows=new List<object>();
            rows.Add(new {foodId=reader.GetInt64(1),code=reader.GetString(2),nameTh=reader.GetString(3),foodTypeName=Text(reader,4),orderedParticipantCount=reader.GetInt32(5),orderedQuantity=reader.GetInt32(6)});
        }
        return result;
    }
    private static void Bind(SqlCommand cmd,long company,long user,string? search,DateOnly from,DateOnly to)
    {
        cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@user",user);
        cmd.Parameters.AddWithValue("@search",(object?)search??DBNull.Value);
        cmd.Parameters.AddWithValue("@from",from.ToDateTime(TimeOnly.MinValue));cmd.Parameters.AddWithValue("@to",to.ToDateTime(TimeOnly.MinValue));
    }
    private static string? Text(SqlDataReader reader,int index)=>reader.IsDBNull(index)?null:reader.GetString(index);
    private static object Error(string message,string description)=>new {message,description};
}
