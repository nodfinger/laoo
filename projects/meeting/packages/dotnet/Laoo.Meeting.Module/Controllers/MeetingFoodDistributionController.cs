using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using LaooMeetingApi.Security;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize, Route("api/company/meeting-food-distribution")]
[RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingFoodDistributionController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "21007";
    private const string OwnershipSql = """
(B.RequesterUserID=@user OR EXISTS
 (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS
 (SELECT 1 FROM dbo.TDADMeetingRoomContact C
  JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=C.EmployeeID AND UE.CompanyID=@company
   AND UE.UserID=@user AND UE.IsActive=1
  JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=@company AND E.IsActive=1
  WHERE C.RoomID=B.RoomID AND C.IsActive=1))
""";

    public sealed record ReceiptItem(long FoodOrderDetailId, int ReceivedQuantity);
    public sealed record ReceiptRequest(List<ReceiptItem>? Items);

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? search,
        [FromQuery] DateOnly? dateFrom,
        [FromQuery] DateOnly? dateTo,
        [FromQuery] string? status,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken token = default)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 100)
            return BadRequest(Error("ตัวกรองไม่ถูกต้อง", "หน้าต้องเริ่มจาก 1 และจำนวนต่อหน้าต้องอยู่ระหว่าง 1 ถึง 100"));
        var from = dateFrom ?? DateOnly.FromDateTime(DateTime.Today);
        var to = dateTo ?? from.AddDays(30);
        if (to < from || to.DayNumber - from.DayNumber > 366)
            return BadRequest(Error("ช่วงวันที่ไม่ถูกต้อง", "วันที่สิ้นสุดต้องไม่น้อยกว่าวันที่เริ่ม และเลือกได้ไม่เกิน 366 วัน"));
        search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        status = string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpperInvariant();
        if (status is not null and not ("PENDING" or "PARTIAL" or "COMPLETED"))
            return BadRequest(Error("สถานะไม่ถูกต้อง", "กรุณาเลือกสถานะการแจกอาหารที่ระบบกำหนด"));

        await using var db = await Open(token);
        if (!await CanAccess(db, company, user, "VIEW", null, token)) return Forbid();
        if (!await Ready(db, token)) return Ok(new { available = false, total = 0, page, pageSize, items = Array.Empty<object>() });
        var rowsSql = RowsCte() + RowsWhere();
        await using var count = new SqlCommand($"""
WITH Rows AS ({rowsSql})
SELECT COUNT_BIG(1) FROM Rows;
""", db);
        Bind(count, company, user, search, from, to, status);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var cmd = new SqlCommand($"""
WITH Rows AS ({rowsSql})
SELECT BookingID,BookingNo,Subject,RoomCode,RoomName,ParticipantID,EmployeeCode,
       ParticipantName,ParticipantNickname,BookingSlotID,StartDateTime,EndDateTime,
       CheckedIn,OrderedQuantity,ReceivedQuantity
FROM Rows
ORDER BY CASE WHEN ReceivedQuantity<OrderedQuantity THEN 0 ELSE 1 END,StartDateTime,ParticipantName
OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""", db);
        Bind(cmd, company, user, search, from, to, status);
        cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
        cmd.Parameters.AddWithValue("@take", pageSize);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
        {
            var ordered = reader.GetInt32(13);
            var received = reader.GetInt32(14);
            items.Add(new
            {
                bookingId = reader.GetInt64(0), bookingNo = reader.GetString(1),
                subject = reader.GetString(2), roomCode = reader.GetString(3),
                roomName = reader.GetString(4), participantId = reader.GetInt64(5),
                employeeCode = Text(reader, 6), participantName = reader.GetString(7),
                participantNickname = Text(reader, 8), slotId = reader.GetInt64(9),
                startDateTime = reader.GetDateTime(10), endDateTime = reader.GetDateTime(11),
                checkedIn = reader.GetBoolean(12), orderedQuantity = ordered,
                receivedQuantity = received, remainingQuantity = ordered - received,
                receiptStatus = received == 0 ? "PENDING" : received < ordered ? "PARTIAL" : "COMPLETED"
            });
        }
        return Ok(new { available = true, total, page, pageSize, items });
    }

    [HttpGet("{participantId:long}/{slotId:long}")]
    public async Task<IActionResult> Get(long participantId, long slotId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await CanAccess(db, company, user, "VIEW", (participantId, slotId), token)) return Forbid();
        var headerSql = """
SELECT TOP(1) B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
 P.BookingParticipantID,E.EmployeeCode,E.FullName,E.NickName,S.BookingSlotID,
 S.StartDateTime,S.EndDateTime,C.CheckInDate
FROM dbo.TDADMeetingRoomBookingParticipant P
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=P.CompanyID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADMeetingParticipantCheckIn C ON C.BookingParticipantID=P.BookingParticipantID
 AND C.BookingSlotID=S.BookingSlotID AND C.CompanyID=B.CompanyID
WHERE B.CompanyID=@company AND P.BookingParticipantID=@participant AND S.BookingSlotID=@slot
 AND P.InvitationStatus='ACCEPTED'
""";
        headerSql += " AND " + OwnershipSql + ";";
        await using var cmd = new SqlCommand(headerSql, db);
        cmd.Parameters.AddWithValue("@company", company); cmd.Parameters.AddWithValue("@user", user);
        cmd.Parameters.AddWithValue("@participant", participantId); cmd.Parameters.AddWithValue("@slot", slotId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound(Error("ไม่พบรายการแจกอาหาร", "ผู้เข้าร่วมหรือรอบประชุมไม่อยู่ในขอบเขตสิทธิ์ของผู้ใช้งาน"));
        var header = new
        {
            bookingId = reader.GetInt64(0), bookingNo = reader.GetString(1), subject = reader.GetString(2),
            roomCode = reader.GetString(3), roomName = reader.GetString(4), participantId = reader.GetInt64(5),
            employeeCode = Text(reader, 6), participantName = reader.GetString(7), participantNickname = Text(reader, 8),
            slotId = reader.GetInt64(9), startDateTime = reader.GetDateTime(10), endDateTime = reader.GetDateTime(11),
            checkInDate = reader.IsDBNull(12) ? (DateTime?)null : reader.GetDateTime(12)
        };
        await reader.CloseAsync();
        var items = await ReadItems(db, company, participantId, token);
        return Ok(new { header, items, canReceive = header.checkInDate is not null && DateTime.Now >= header.startDateTime && DateTime.Now < header.endDateTime });
    }

    [HttpPut("{participantId:long}/{slotId:long}")]
    public async Task<IActionResult> Save(long participantId, long slotId, ReceiptRequest request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        if (request.Items is null || request.Items.Count is < 1 or > 100
            || request.Items.Any(x => x is null || x.FoodOrderDetailId <= 0 || x.ReceivedQuantity is < 0 or > 99)
            || request.Items.Select(x => x.FoodOrderDetailId).Distinct().Count() != request.Items.Count)
            return BadRequest(Error("จำนวนรับอาหารไม่ถูกต้อง", "ส่งรายการอาหารที่ไม่ซ้ำ พร้อมยอดรับสะสมเป็นจำนวนเต็ม 0 ถึง 99"));
        await using var db = await Open(token);
        if (!await CanAccess(db, company, user, "EDIT", (participantId, slotId), token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, token);
        await using var access = new SqlCommand("""
SELECT TOP(1) B.BookingID,C.ParticipantCheckInID,C.CheckInDate,S.StartDateTime,S.EndDateTime
FROM dbo.TDADMeetingRoomBookingParticipant P
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID AND S.BookingSlotID=@slot
JOIN dbo.TDADMeetingParticipantCheckIn C ON C.BookingParticipantID=P.BookingParticipantID AND C.BookingSlotID=S.BookingSlotID AND C.CompanyID=B.CompanyID
WHERE B.CompanyID=@company AND P.BookingParticipantID=@participant AND P.InvitationStatus='ACCEPTED'
  AND B.BookingStatus='APPROVED' AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE();
""", db, tx);
        access.Parameters.AddWithValue("@company", company); access.Parameters.AddWithValue("@participant", participantId); access.Parameters.AddWithValue("@slot", slotId);
        await using var ar = await access.ExecuteReaderAsync(token);
        if (!await ar.ReadAsync(token)) return Conflict(Error("ยังแจกอาหารไม่ได้", "ผู้เข้าร่วมต้องตอบรับ เช็กอินแล้ว และอยู่ในช่วงเวลาประชุมที่อนุมัติ"));
        var bookingId = ar.GetInt64(0); var checkInId = ar.GetInt64(1); await ar.CloseAsync();
        await using var order = new SqlCommand("SELECT BookingFoodOrderID FROM dbo.TDADMeetingBookingFoodOrder WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND BookingID=@booking AND BookingParticipantID=@participant AND IsCancelled=0", db, tx);
        order.Parameters.AddWithValue("@company", company); order.Parameters.AddWithValue("@booking", bookingId); order.Parameters.AddWithValue("@participant", participantId);
        var orderId = await order.ExecuteScalarAsync(token);
        if (orderId is null) return Conflict(Error("ไม่มีรายการอาหารที่สั่ง", "ผู้เข้าร่วมคนนี้ไม่มีคำสั่งอาหารที่ใช้งานอยู่"));
        var existing = await ReadItems(db, company, participantId, token, tx, Convert.ToInt64(orderId));
        var map = existing.ToDictionary(x => Convert.ToInt64(x.GetType().GetProperty("foodOrderDetailId")!.GetValue(x)));
        foreach (var item in request.Items)
        {
            if (!map.TryGetValue(item.FoodOrderDetailId, out var current)) return Conflict(Error("รายการอาหารไม่ถูกต้อง", "รายการที่ส่งมาไม่อยู่ในคำสั่งอาหารของผู้เข้าร่วม"));
            var currentReceived = Convert.ToInt32(current.GetType().GetProperty("receivedQuantity")!.GetValue(current));
            var ordered = Convert.ToInt32(current.GetType().GetProperty("orderedQuantity")!.GetValue(current));
            if (item.ReceivedQuantity < currentReceived || item.ReceivedQuantity > ordered)
                return Conflict(Error("บันทึกรับอาหารไม่ได้", "ยอดรับต้องไม่น้อยกว่ายอดเดิมและไม่เกินยอดสั่ง"));
        }
        foreach (var item in request.Items)
        {
            await using var save = new SqlCommand("""
DECLARE @now datetime2(7)=SYSUTCDATETIME();
UPDATE dbo.TDADMeetingFoodReceipt SET ReceivedQuantity=@quantity,ReceivedByUserID=@user,
 ReceivedAtUtc=@now,ParticipantCheckInID=@checkin,ReceiptMethod='DELEGATE'
WHERE CompanyID=@company AND BookingFoodOrderDetailID=@detail;
IF @@ROWCOUNT=0
 INSERT dbo.TDADMeetingFoodReceipt(CompanyID,BookingFoodOrderDetailID,ParticipantCheckInID,ReceivedQuantity,ReceivedByUserID,ReceivedAtUtc,ReceiptMethod)
 VALUES(@company,@detail,@checkin,@quantity,@user,@now,'DELEGATE');
INSERT dbo.TDADMeetingFoodReceiptHistory(FoodReceiptID,ParticipantCheckInID,PreviousQuantity,ReceivedQuantity,ReceivedByUserID,ReceivedAtUtc,ReceiptMethod)
SELECT FoodReceiptID,@checkin,@previous,@quantity,@user,@now,'DELEGATE'
FROM dbo.TDADMeetingFoodReceipt WHERE CompanyID=@company AND BookingFoodOrderDetailID=@detail;
""", db, tx);
            save.Parameters.AddWithValue("@company", company); save.Parameters.AddWithValue("@detail", item.FoodOrderDetailId);
            save.Parameters.AddWithValue("@checkin", checkInId); save.Parameters.AddWithValue("@quantity", item.ReceivedQuantity);
            save.Parameters.AddWithValue("@previous", Convert.ToInt32(map[item.FoodOrderDetailId].GetType().GetProperty("receivedQuantity")!.GetValue(map[item.FoodOrderDetailId])));
            save.Parameters.AddWithValue("@user", user);
            await save.ExecuteNonQueryAsync(token);
        }
        await tx.CommitAsync(token);
        return Ok(new { bookingId, participantId, slotId, items = await ReadItems(db, company, participantId, token) });
    }

    private string RowsCte() => """
SELECT B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH AS RoomName,
 P.BookingParticipantID AS ParticipantID,E.EmployeeCode,E.FullName AS ParticipantName,
 E.NickName AS ParticipantNickname,S.BookingSlotID,S.StartDateTime,S.EndDateTime,
 CAST(CASE WHEN C.ParticipantCheckInID IS NULL THEN 0 ELSE 1 END AS bit) CheckedIn,
 SUM(D.Quantity) OrderedQuantity,SUM(ISNULL(FR.ReceivedQuantity,0)) ReceivedQuantity
FROM dbo.TDADMeetingRoomBookingParticipant P
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=P.CompanyID AND E.IsActive=1
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
JOIN dbo.TDADMeetingBookingFoodOrder H ON H.CompanyID=B.CompanyID AND H.BookingID=B.BookingID AND H.BookingParticipantID=P.BookingParticipantID AND H.IsCancelled=0
JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID
LEFT JOIN dbo.TDADMeetingFoodReceipt FR ON FR.CompanyID=H.CompanyID AND FR.BookingFoodOrderDetailID=D.BookingFoodOrderDetailID
LEFT JOIN dbo.TDADMeetingParticipantCheckIn C ON C.CompanyID=B.CompanyID AND C.BookingParticipantID=P.BookingParticipantID AND C.BookingSlotID=S.BookingSlotID
""";

    private string RowsWhere()
    {
        var where = """
 WHERE B.CompanyID=@company AND P.InvitationStatus='ACCEPTED'
 AND S.StartDateTime<DATEADD(day,1,CAST(@to AS datetime2)) AND S.EndDateTime>=CAST(@from AS datetime2)
 """;
        where += " AND " + OwnershipSql + """
 AND (@search IS NULL OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%'
      OR E.EmployeeCode LIKE N'%'+@search+N'%' OR E.FullName LIKE N'%'+@search+N'%' OR E.NickName LIKE N'%'+@search+N'%')
GROUP BY B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,P.BookingParticipantID,
 E.EmployeeCode,E.FullName,E.NickName,S.BookingSlotID,S.StartDateTime,S.EndDateTime,C.ParticipantCheckInID
HAVING @status IS NULL OR (@status='PENDING' AND SUM(ISNULL(FR.ReceivedQuantity,0))=0)
 OR (@status='PARTIAL' AND SUM(ISNULL(FR.ReceivedQuantity,0))>0 AND SUM(ISNULL(FR.ReceivedQuantity,0))<SUM(D.Quantity))
 OR (@status='COMPLETED' AND SUM(ISNULL(FR.ReceivedQuantity,0))>=SUM(D.Quantity))
""";
        return where;
    }

    private static async Task<List<object>> ReadItems(SqlConnection db,long company,long participant,CancellationToken token,SqlTransaction? tx=null,long? orderId=null)
    {
        await using var cmd=new SqlCommand("""
SELECT D.BookingFoodOrderDetailID,F.FoodID,F.FoodNameTH,D.Quantity,ISNULL(R.ReceivedQuantity,0)
FROM dbo.TDADMeetingBookingFoodOrderDetail D
JOIN dbo.TDADMeetingBookingFoodOrder H ON H.BookingFoodOrderID=D.BookingFoodOrderID AND H.CompanyID=@company AND H.BookingParticipantID=@participant AND H.IsCancelled=0
JOIN dbo.TDADMeetingFood F ON F.FoodID=D.FoodID AND F.CompanyID=H.CompanyID
LEFT JOIN dbo.TDADMeetingFoodReceipt R ON R.CompanyID=H.CompanyID AND R.BookingFoodOrderDetailID=D.BookingFoodOrderDetailID
WHERE (@order IS NULL OR H.BookingFoodOrderID=@order)
ORDER BY F.FoodNameTH,D.BookingFoodOrderDetailID;
""",db,tx);
        cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@participant",participant);cmd.Parameters.AddWithValue("@order",(object?)orderId??DBNull.Value);
        await using var reader=await cmd.ExecuteReaderAsync(token);var rows=new List<object>();
        while(await reader.ReadAsync(token)){var ordered=reader.GetInt32(3);var received=reader.GetInt32(4);rows.Add(new{foodOrderDetailId=reader.GetInt64(0),foodId=reader.GetInt64(1),foodName=reader.GetString(2),orderedQuantity=ordered,receivedQuantity=received,remainingQuantity=ordered-received});}
        return rows;
    }

    private async Task<bool> CanAccess(SqlConnection db,long company,long user,string action,(long participant,long slot)? target,CancellationToken token)
    {
        if (await MeetingFoodPlanAccess.Allowed(db,User,action,token,ScreenCode)) return true;
        if (target is null)
        {
            var anySql = """
SELECT CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADMeetingRoomBooking B
 WHERE B.CompanyID=@company
""";
            anySql += " AND " + OwnershipSql + ") THEN 1 ELSE 0 END";
            await using var any = new SqlCommand(anySql, db);
            any.Parameters.AddWithValue("@company", company);
            any.Parameters.AddWithValue("@user", user);
            return Convert.ToInt32(await any.ExecuteScalarAsync(token)) == 1;
        }
        var targetSql = """
SELECT CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADMeetingRoomBookingParticipant P
 JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
 JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID AND S.BookingSlotID=@slot
 WHERE B.CompanyID=@company AND P.BookingParticipantID=@participant
""";
        targetSql += " AND " + OwnershipSql + ") THEN 1 ELSE 0 END";
        await using var cmd=new SqlCommand(targetSql,db);
        cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@user",user);cmd.Parameters.AddWithValue("@participant",target.Value.participant);cmd.Parameters.AddWithValue("@slot",target.Value.slot);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token))==1;
    }

    private bool Scope(out long company,out long user){company=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&company>0&&long.TryParse(User.FindFirstValue("user_id"),out user)&&user>0;}
    private async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    private static void Bind(SqlCommand c,long company,long user,string? search,DateOnly from,DateOnly to,string? status){c.Parameters.AddWithValue("@company",company);c.Parameters.AddWithValue("@user",user);c.Parameters.AddWithValue("@search",(object?)search??DBNull.Value);c.Parameters.AddWithValue("@from",from.ToDateTime(TimeOnly.MinValue));c.Parameters.AddWithValue("@to",to.ToDateTime(TimeOnly.MinValue));c.Parameters.AddWithValue("@status",(object?)status??DBNull.Value);}
    private static async Task<bool> Ready(SqlConnection db,CancellationToken token){await using var c=new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDADMeetingFoodReceipt',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.TDADMeetingFoodReceiptHistory',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrder',N'U') IS NOT NULL THEN 1 ELSE 0 END",db);return Convert.ToInt32(await c.ExecuteScalarAsync(token))==1;}
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
    private static object Error(string message,string description)=>new{message,description};
}
