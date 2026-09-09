using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/my-meeting-invitations"), Authorize]
[LaooMeetingApi.Security.RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingInvitationController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "21003";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new { view = await Allowed(connection, "VIEW", token), edit = await Allowed(connection, "EDIT", token) });
    }

    [HttpGet]
    public async Task<IActionResult> List(string? search = null, string? status = null, int page = 1, int pageSize = 20, CancellationToken token = default)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        var isAdmin = await IsCompanyAdmin(connection, company, user, token);
        var employee = await EmployeeId(connection, company, user, token);
        if (!isAdmin && employee is null) return BadRequest(Error("ไม่พบข้อมูลพนักงานของผู้ใช้งาน", "กรุณาผูก User Login กับพนักงานก่อนเปิดคำเชิญของฉัน"));
        const string filter = @"
FROM dbo.TDADMeetingRoomBookingParticipant P
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADUserEmployee RUE ON RUE.UserID=B.RequesterUserID AND RUE.CompanyID=B.CompanyID AND RUE.IsActive=1
LEFT JOIN dbo.TDADEmployee RE ON RE.EmployeeID=COALESCE(B.RequesterEmployeeID,RUE.EmployeeID) AND RE.CompanyID=B.CompanyID
INNER JOIN dbo.TDADEmployee PE ON PE.EmployeeID=P.EmployeeID AND PE.CompanyID=P.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodPlan FP ON FP.BookingID=B.BookingID AND FP.CompanyID=B.CompanyID AND FP.IsActive=1
WHERE P.CompanyID=@company AND (@admin=1 OR P.EmployeeID=@employee) AND B.BookingStatus='APPROVED'
  AND S.EndDateTime>=GETDATE()
  AND (@status IS NULL OR @status='' OR P.InvitationStatus=@status)
  AND (@search IS NULL OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%' OR R.RoomCode LIKE N'%'+@search+N'%' OR R.RoomNameTH LIKE N'%'+@search+N'%' OR PE.EmployeeCode LIKE N'%'+@search+N'%' OR PE.FullName LIKE N'%'+@search+N'%')";
        var countSql = $"SELECT COUNT_BIG(DISTINCT P.BookingParticipantID) {filter};";
        await using var count = new SqlCommand(countSql, connection); Bind(count, company, employee, isAdmin, search, status);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        var sql = $@"
SELECT P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
       MIN(S.StartDateTime),MAX(S.EndDateTime),P.InvitationStatus,P.ResponseDate,P.Remark,
       PE.EmployeeCode,PE.FullName,RE.EmployeeCode,RE.FullName,FP.OrderCutoffDateTime,
       CASE WHEN P.EmployeeID=@employee THEN 1 ELSE 0 END,
       (SELECT COUNT_BIG(1) FROM dbo.TDADMeetingBookingFoodOption FO WHERE FO.BookingID=B.BookingID AND FO.CompanyID=B.CompanyID)
{filter}
GROUP BY P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
         P.InvitationStatus,P.ResponseDate,P.Remark,PE.EmployeeCode,PE.FullName,RE.EmployeeCode,RE.FullName,FP.OrderCutoffDateTime,P.EmployeeID,B.CreateDate
ORDER BY MIN(S.StartDateTime),B.CreateDate
OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;";
        await using var command = new SqlCommand(sql, connection); Bind(command, company, employee, isAdmin, search, status); Add(command, "@skip", (page - 1) * pageSize); Add(command, "@take", pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            participantId = reader.GetInt64(0), bookingId = reader.GetInt64(1), bookingNo = Text(reader, 2), subject = reader.GetString(3),
            roomCode = reader.GetString(4), roomName = reader.GetString(5), startDateTime = reader.GetDateTime(6), endDateTime = reader.GetDateTime(7),
            invitationStatus = reader.GetString(8), responseDate = Date(reader, 9), remark = Text(reader, 10), participantCode = Text(reader, 11),
            participantName = Text(reader, 12), organizerCode = Text(reader, 13), organizerName = Text(reader, 14),
            orderCutoffDateTime = Date(reader, 15), foodCount = Convert.ToInt32(reader.GetInt64(17)), canRespond = reader.GetInt32(16) == 1,
        });
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("{participantId:long}")]
    public async Task<IActionResult> Get(long participantId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        var isAdmin = await IsCompanyAdmin(connection, company, user, token);
        var employee = await EmployeeId(connection, company, user, token);
        if (!isAdmin && employee is null) return Forbid();
        const string headerSql = @"
SELECT P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,B.Description,R.RoomCode,R.RoomNameTH,
       MIN(S.StartDateTime),MAX(S.EndDateTime),P.InvitationStatus,P.Remark,RE.FullName,PE.FullName,FP.OrderCutoffDateTime,
       CASE WHEN P.EmployeeID=@employee THEN 1 ELSE 0 END,
       CASE WHEN P.EmployeeID=@employee AND P.InvitationStatus<>'DECLINED' AND FP.IsActive=1 AND FP.OrderCutoffDateTime>GETDATE() THEN 1 ELSE 0 END
FROM dbo.TDADMeetingRoomBookingParticipant P
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.BookingStatus='APPROVED'
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADUserEmployee RUE ON RUE.UserID=B.RequesterUserID AND RUE.CompanyID=B.CompanyID AND RUE.IsActive=1
LEFT JOIN dbo.TDADEmployee RE ON RE.EmployeeID=COALESCE(B.RequesterEmployeeID,RUE.EmployeeID) AND RE.CompanyID=B.CompanyID
INNER JOIN dbo.TDADEmployee PE ON PE.EmployeeID=P.EmployeeID AND PE.CompanyID=P.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodPlan FP ON FP.BookingID=B.BookingID AND FP.CompanyID=B.CompanyID AND FP.IsActive=1
WHERE P.BookingParticipantID=@participant AND P.CompanyID=@company AND (@admin=1 OR P.EmployeeID=@employee) AND S.EndDateTime>=GETDATE()
GROUP BY P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,B.Description,R.RoomCode,R.RoomNameTH,P.InvitationStatus,P.Remark,RE.FullName,PE.FullName,FP.OrderCutoffDateTime,FP.IsActive,P.EmployeeID;";
        await using var header = new SqlCommand(headerSql, connection); Add(header, "@participant", participantId); Add(header, "@company", company); Add(header, "@employee", employee); Add(header, "@admin", isAdmin ? 1 : 0);
        await using var reader = await header.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound(Error("ไม่พบคำเชิญ", $"คำเชิญ {participantId} ไม่อยู่ในขอบเขตของผู้ใช้งาน"));
        var bookingId = reader.GetInt64(1);
        var result = new
        {
            participantId = reader.GetInt64(0), bookingId, bookingNo = Text(reader, 2), subject = reader.GetString(3), description = Text(reader, 4),
            roomCode = reader.GetString(5), roomName = reader.GetString(6), startDateTime = reader.GetDateTime(7), endDateTime = reader.GetDateTime(8),
            invitationStatus = reader.GetString(9), remark = Text(reader, 10), organizerName = Text(reader, 11), participantName = Text(reader, 12), orderCutoffDateTime = Date(reader, 13), canRespond = reader.GetInt32(14) == 1, canOrder = reader.GetInt32(15) == 1,
        };
        await reader.CloseAsync();
        const string foodSql = @"
SELECT F.FoodID,F.FoodCode,F.FoodNameTH,T.Name,F.FoodImageUrl,ISNULL(OD.Quantity,0)
FROM dbo.TDADMeetingBookingFoodOption O
INNER JOIN dbo.TDADMeetingFood F ON F.FoodID=O.FoodID AND F.CompanyID=O.CompanyID
OUTER APPLY
(
    SELECT TOP (1) D.Quantity
    FROM dbo.TDADMeetingBookingFoodOrder H
    INNER JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID
    WHERE H.CompanyID=@company AND H.BookingID=@booking AND H.BookingParticipantID=@participant AND D.FoodID=F.FoodID
) OD
OUTER APPLY
(
    SELECT TOP (1) M.Name,M.Seq
    FROM dbo.TDSTMaster M
    WHERE M.MasterGroupCode='011'
      AND M.MasterCode=F.FoodTypeCode
      AND M.IsActive=1
      AND M.OwnerType='C'
      AND M.OwnerCompanyID=@company
) T
WHERE O.BookingID=@booking AND O.CompanyID=@company
ORDER BY ISNULL(T.Seq,0),F.FoodCode;";
        await using var food = new SqlCommand(foodSql, connection); Add(food, "@booking", bookingId); Add(food, "@company", company); Add(food, "@participant", participantId);
        await using var foodReader = await food.ExecuteReaderAsync(token);
        var foods = new List<object>();
        while (await foodReader.ReadAsync(token)) foods.Add(new { foodId = foodReader.GetInt64(0), code = foodReader.GetString(1), nameTh = foodReader.GetString(2), foodTypeName = Text(foodReader, 3), imageUrl = Text(foodReader, 4), orderQuantity = foodReader.GetInt32(5) });
        return Ok(new { invitation = result, foods });
    }

    [HttpPut("{participantId:long}/response")]
    public async Task<IActionResult> Respond(long participantId, InvitationResponseRequest request, CancellationToken token)
    {
        var status = request.Status?.Trim().ToUpperInvariant();
        if (status is not ("PENDING" or "ACCEPTED" or "DECLINED")) return BadRequest(Error("สถานะตอบรับไม่ถูกต้อง", "เลือกได้เฉพาะ รอตอบรับ เข้าร่วม หรือไม่เข้าร่วม"));
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "EDIT", token)) return Forbid();
        var employee = await EmployeeId(connection, company, user, token);
        if (employee is null) return Forbid();
        const string sql = @"
UPDATE P SET InvitationStatus=@status,ResponseDate=CASE WHEN @status='PENDING' THEN NULL ELSE SYSUTCDATETIME() END,Remark=@remark
FROM dbo.TDADMeetingRoomBookingParticipant P
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.BookingStatus='APPROVED'
WHERE P.BookingParticipantID=@participant AND P.CompanyID=@company AND P.EmployeeID=@employee
  AND EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID AND S.EndDateTime>=GETDATE());";
        await using var command = new SqlCommand(sql, connection); Add(command, "@status", status); Add(command, "@remark", string.IsNullOrWhiteSpace(request.Remark) ? null : request.Remark.Trim()); Add(command, "@participant", participantId); Add(command, "@company", company); Add(command, "@employee", employee.Value);
        return await command.ExecuteNonQueryAsync(token) == 0 ? NotFound(Error("ไม่พบคำเชิญที่แก้ไขได้", "คำเชิญอาจสิ้นสุดหรือไม่อยู่ในบัญชีผู้ใช้นี้")) : Ok(new { participantId, status });
    }

    [HttpPut("{participantId:long}/food-order")]
    public async Task<IActionResult> SaveFoodOrder(long participantId, FoodOrderRequest request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "EDIT", token)) return Forbid();
        var employee = await EmployeeId(connection, company, user, token);
        if (employee is null) return Forbid();
        var items = (request.Items ?? new List<FoodOrderItem>()).GroupBy(x => x.FoodId).Select(x => new FoodOrderItem(x.Key, x.Sum(y => y.Quantity))).ToList();
        if (items.Any(x => x.FoodId <= 0 || x.Quantity is < 1 or > 99)) return BadRequest(Error("รายการอาหารไม่ถูกต้อง", "จำนวนอาหารต้องอยู่ระหว่าง 1 ถึง 99"));
        await using var header = new SqlCommand(@"
SELECT TOP (1) P.BookingID,P.EmployeeID
FROM dbo.TDADMeetingRoomBookingParticipant P
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.BookingStatus='APPROVED'
INNER JOIN dbo.TDADMeetingBookingFoodPlan FP ON FP.BookingID=B.BookingID AND FP.CompanyID=B.CompanyID AND FP.IsActive=1 AND FP.OrderCutoffDateTime>GETDATE()
WHERE P.BookingParticipantID=@participant AND P.CompanyID=@company AND P.EmployeeID=@employee AND P.InvitationStatus<>'DECLINED'
  AND EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID AND S.EndDateTime>=GETDATE());", connection);
        Add(header, "@participant", participantId); Add(header, "@company", company); Add(header, "@employee", employee.Value);
        await using var reader = await header.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound(Error("ไม่สามารถสั่งอาหารได้", "คำเชิญ เมนูอาหาร หรือเวลาปิดรับสั่งไม่พร้อมใช้งาน"));
        var bookingId = reader.GetInt64(0); var orderedFor = reader.GetInt64(1); await reader.CloseAsync();
        if (items.Count > 0)
        {
            var parameters = string.Join(',', items.Select((_, index) => $"@food{index}"));
            await using var allowed = new SqlCommand($"SELECT COUNT_BIG(1) FROM dbo.TDADMeetingBookingFoodOption WHERE BookingID=@booking AND CompanyID=@company AND FoodID IN ({parameters})", connection);
            Add(allowed, "@booking", bookingId); Add(allowed, "@company", company);
            for (var index = 0; index < items.Count; index++) Add(allowed, $"@food{index}", items[index].FoodId);
            if (Convert.ToInt32(await allowed.ExecuteScalarAsync(token)) != items.Count) return BadRequest(Error("มีอาหารที่ไม่ได้เปิดให้เลือก", "กรุณาเลือกเฉพาะรายการอาหารของการประชุมนี้"));
        }
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            long? orderId;
            await using (var find = new SqlCommand("SELECT BookingFoodOrderID FROM dbo.TDADMeetingBookingFoodOrder WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND BookingParticipantID=@participant", connection, transaction))
            { Add(find, "@company", company); Add(find, "@participant", participantId); var value = await find.ExecuteScalarAsync(token); orderId = value is null ? null : Convert.ToInt64(value); }
            // The header lock serializes this replacement with attendance food receipts.
            // Once food has been issued, keep both header and detail IDs (and their audit trail).
            if (orderId is not null)
            {
                await using var receiptSchema = new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDADMeetingFoodReceipt',N'U') IS NULL THEN 0 ELSE 1 END", connection, transaction);
                if (Convert.ToInt32(await receiptSchema.ExecuteScalarAsync(token)) == 1)
                {
                    await using var received = new SqlCommand(@"
SELECT CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADMeetingFoodReceipt R
 INNER JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderDetailID=R.BookingFoodOrderDetailID
 WHERE R.CompanyID=@company AND D.BookingFoodOrderID=@order) THEN 1 ELSE 0 END;", connection, transaction);
                    Add(received, "@company", company); Add(received, "@order", orderId.Value);
                    if (Convert.ToInt32(await received.ExecuteScalarAsync(token)) == 1)
                        return Conflict(Error("แก้ไขคำสั่งอาหารไม่ได้", "มีการรับอาหารแล้ว จึงไม่สามารถแก้ไขหรือลบคำสั่งนี้ได้ กรุณาตรวจสอบรายการรับอาหาร"));
                }
            }
            if (items.Count == 0)
            {
                if (orderId is not null) { await using var remove = new SqlCommand("DELETE FROM dbo.TDADMeetingBookingFoodOrder WHERE BookingFoodOrderID=@order", connection, transaction); Add(remove, "@order", orderId.Value); await remove.ExecuteNonQueryAsync(token); }
                await transaction.CommitAsync(token); return Ok(new { participantId, itemCount = 0 });
            }
            if (orderId is null)
            {
                await using var insert = new SqlCommand("INSERT dbo.TDADMeetingBookingFoodOrder(CompanyID,BookingID,BookingParticipantID,OrderedForEmployeeID,OrderedByUserID,CreateBy) VALUES(@company,@booking,@participant,@for,@user,@user); SELECT CONVERT(bigint,SCOPE_IDENTITY());", connection, transaction);
                Add(insert, "@company", company); Add(insert, "@booking", bookingId); Add(insert, "@participant", participantId); Add(insert, "@for", orderedFor); Add(insert, "@user", user); orderId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            }
            else
            {
                await using var update = new SqlCommand("UPDATE dbo.TDADMeetingBookingFoodOrder SET OrderedByUserID=@user,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE BookingFoodOrderID=@order; DELETE FROM dbo.TDADMeetingBookingFoodOrderDetail WHERE BookingFoodOrderID=@order;", connection, transaction); Add(update, "@user", user); Add(update, "@order", orderId.Value); await update.ExecuteNonQueryAsync(token);
            }
            foreach (var item in items)
            {
                await using var detail = new SqlCommand("INSERT dbo.TDADMeetingBookingFoodOrderDetail(BookingFoodOrderID,FoodID,Quantity,CreateBy) VALUES(@order,@food,@quantity,@user)", connection, transaction);
                Add(detail, "@order", orderId.Value); Add(detail, "@food", item.FoodId); Add(detail, "@quantity", item.Quantity); Add(detail, "@user", user); await detail.ExecuteNonQueryAsync(token);
            }
            await transaction.CommitAsync(token);
            return Ok(new { participantId, itemCount = items.Count });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }
    private async Task<long?> EmployeeId(SqlConnection connection, long company, long user, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT TOP 1 EmployeeID FROM dbo.TDADUserEmployee WHERE UserID=@user AND CompanyID=@company AND IsActive=1 ORDER BY UserEmployeeID", connection); Add(command, "@user", user); Add(command, "@company", company);
        var value = await command.ExecuteScalarAsync(token); return value is null ? null : Convert.ToInt64(value);
    }
    private void Bind(SqlCommand command, long company, long? employee, bool isAdmin, string? search, string? status) { Add(command, "@company", company); Add(command, "@employee", employee); Add(command, "@admin", isAdmin ? 1 : 0); Add(command, "@search", string.IsNullOrWhiteSpace(search) ? null : search.Trim()); Add(command, "@status", string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpperInvariant()); }
    private static async Task<bool> IsCompanyAdmin(SqlConnection connection, long company, long user, CancellationToken token) { await using var command = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) THEN 1 ELSE 0 END", connection); Add(command, "@user", user); Add(command, "@company", company); return Convert.ToBoolean(await command.ExecuteScalarAsync(token)); }
    private async Task<bool> Allowed(SqlConnection connection, string action, CancellationToken token)
    {
        if (!Scope(out var company, out var user) || !long.TryParse(User.FindFirstValue("project_id"), out var project)) return false;
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection); Add(command, "@user", user); Add(command, "@company", company); Add(command, "@project", project); Add(command, "@screen", ScreenCode); Add(command, "@action", action); return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
    private bool Scope(out long company, out long user)
    {
        company = 0; user = 0;
        return long.TryParse(User.FindFirstValue("company_id"), out company) && company > 0
            && long.TryParse(User.FindFirstValue("user_id"), out user) && user > 0
            && string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);
    }
    private async Task<SqlConnection> Open(CancellationToken token) { var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await connection.OpenAsync(token); return connection; }
    private static object Error(string message, string description) => new { message, description };
    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private static DateTime? Date(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetDateTime(index);
    private static void Add(SqlCommand command, string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
}

public sealed record InvitationResponseRequest(string? Status, string? Remark);
public sealed record FoodOrderRequest(List<FoodOrderItem>? Items);
public sealed record FoodOrderItem(long FoodId, int Quantity);
